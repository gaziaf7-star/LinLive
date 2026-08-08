import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:get/get.dart';

import 'package:intl/intl.dart';
import 'package:meetlivepro/app/modules/moments/views/widgets/create_post.dart';

import 'package:shimmer/shimmer.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';

import '../../store/controllers/store1_controller.dart';
import '../controllers/moments_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MomentsView extends StatefulWidget {
  MomentsView({super.key});

  @override
  State<MomentsView> createState() => _MomentsViewState();
}

class _MomentsViewState extends State<MomentsView>
    with TickerProviderStateMixin {
  Map<int, AnimationController> _animationControllers = {};
  final momentsController = Get.find<MomentsController>();

  @override
  void initState() {
    super.initState();
    _animationControllers = {};
  }

  @override
  void dispose() {
    _animationControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _openCreatePost(MomentsController controller) {
    if (!controller.canCreatePost()) {
      return;
    }

    Get.to(
      createPostView(),
      transition: Transition.rightToLeftWithFade,
    );
  }

  @override
  Widget build(BuildContext context) {
    Store1Controller store1controller = Get.put(Store1Controller());
    MomentsController momentsController = Get.put(MomentsController());

    momentsController.getPostList();
    return Scaffold(
      backgroundColor: kAppColor2.withOpacity(.2),
      body: Column(
        children: [

          // Post input row

          Container(

            decoration: BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/new/Screenshot 2026-05-01 100344.png'),fit: BoxFit.cover)
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            child: Column(
              children: [

                Image.asset('assets/new/momints__1_-removebg-preview.png',height: kHeight*0.13,),
                Row(
                  children: [


                    // Profile
                    Obx(() {
                      final userProfile = authController.userProfile.value;
                      final user = userProfile.user;

                      final profileImage = user?.profileImage ?? '';

                      // Only asset_histories frame, entry_histories never use here
                      final framePath =
                          userProfile.assetHistories?.asset?.asset?.toString() ?? '';

                      final agencyId =
                          int.tryParse(user?.agencyId?.toString() ?? '0') ?? 0;

                      final bool hasUserFrame =
                          userProfile.assetHistories != null &&
                              framePath.isNotEmpty &&
                              userProfile.assetHistories?.asset?.type == 'Frame';

                      final bool hasAgencyFrame = !hasUserFrame && agencyId > 0;

                      final baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
                      final frameUrl = '$baseUrl/$framePath';

                      print('Asset Histories => ${userProfile.assetHistories}');
                      print('Entry Histories => ${userProfile.entryHistories}');
                      print('Frame Path => $framePath');
                      print('Frame Url => $frameUrl');
                      print('Has User Frame => $hasUserFrame');

                      return Container(
                        height: kHeight * 0.1,
                        width: kHeight * 0.11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(profileImage),
                                  fit: BoxFit.cover,
                                  height: 80,
                                  width: 80,
                                  placeholder: (c, u) =>
                                  const CircularProgressIndicator(strokeWidth: 2),
                                  errorWidget: (c, u, e) =>
                                  const Icon(Icons.person, size: 50),
                                ),
                              ),
                            ),

                            if (hasUserFrame)
                              SizedBox(
                                height: kHeight * 0.1,
                                width: kHeight * 0.11,
                                child: framePath.toLowerCase().endsWith('.svga')
                                    ? SVGAEasyPlayer(
                                  resUrl: frameUrl,
                                  fit: BoxFit.cover,
                                )
                                    : CachedNetworkImage(
                                  imageUrl: frameUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if (hasAgencyFrame)
                              SizedBox(
                                height: kHeight * 0.1,
                                width: kHeight * 0.11,
                                child: SVGAEasyPlayer(
                                  assetsName: 'assets/svga/Frame/Agency frame.svga',
                                  fit: BoxFit.cover,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(width: 10),

                    // Fake textfield
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _openCreatePost(momentsController);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child:  Text(
                            ("What's on your mind?").appTr,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    IconButton(
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: () {
                        _openCreatePost(momentsController);
                      },
                      icon: const Icon(Icons.photo_library,
                          color: Colors.white, size: 24),
                    )
                  ],
                ),
                SizedBox(height: 10,)
              ],
            ),
          ),


          /// Post List
          Expanded(
            child: Obx(() {
              if (momentsController.isLoading.value) {
                return ListView.builder(

                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: kAppColor2.withOpacity(.2)
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor:
                                Colors.grey.shade100,
                                child: const CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                    Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Shimmer.fromColors(
                                  baseColor:
                                  Colors.grey.shade300,
                                  highlightColor:
                                  Colors.grey.shade100,
                                  child: Container(
                                    height: 16,
                                    width: double.infinity,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor:
                            Colors.grey.shade100,
                            child: Container(
                              height: 12,
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                  right: 50),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(3, (i) {
                              return Container(
                                margin: const EdgeInsets.only(
                                    right: 8),
                                child: Shimmer.fromColors(
                                  baseColor:
                                  Colors.grey.shade300,
                                  highlightColor:
                                  Colors.grey.shade100,
                                  child: Container(
                                    height: 60,
                                    width: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              /// Real Post List
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: momentsController.postList.length,
                itemBuilder:
                    (BuildContext context, int postIndex) {
                  final post =
                  momentsController.postList[postIndex];
                  print('Momemnt Post List $post');
                  List<String> images = [];

                  if (post['post'] != null &&
                      post['post'].toString().isNotEmpty) {
                    images = List<String>.from(
                        jsonDecode(post['post']));
                  }

                  String reactionType = post['like'] == 'yes'
                      ? (post['reaction'] ?? 'like')
                      : 'none';

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: kAppColor2.withOpacity(.02),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // Header
                        ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 45,
                                width: 45,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                  BorderRadius.circular(
                                      100),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                    ImageHelper.getImageUrl(
                                        "${post['user']['profile_image']}"),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (post['user']['agency_id'] !=
                                  null &&
                                  post['user']['agency_id']
                                      .toString() !=
                                      "0" &&
                                  post['user']['agency_id']
                                      .toString()
                                      .isNotEmpty)
                                SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: SVGAEasyPlayer(
                                    assetsName:
                                    'assets/svga/Frame/Agency frame.svga',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if (post['user'][
                              'asset_purchase_history'] !=
                                  null &&
                                  post['user'][
                                  'asset_purchase_history']
                                  ['asset'] !=
                                      null &&
                                  post['user'][
                                  'asset_purchase_history']
                                  ['asset']['asset'] !=
                                      null)
                              // Check if the asset path ends with .svga
                                (post['user']['asset_purchase_history']
                                ['asset']['asset']
                                    .toString()
                                    .endsWith('.svga'))
                                    ? SizedBox(
                                  height: kHeight * 0.07,
                                  width: kHeight * 0.07,
                                  child: SVGAEasyPlayer(
                                    resUrl:
                                    '$kDomainUrl/${post['user']['asset_purchase_history']['asset']['asset']}',
                                    fit: BoxFit.cover,
                                  ),
                                )
                                    : CachedNetworkImage(
                                  imageUrl:
                                  "$kDomainUrl/${post['user']['asset_purchase_history']['asset']['asset']}",
                                  height: kHeight * 0.07,
                                  width: kHeight * 0.07,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) =>
                                      Container(
                                        height:
                                        kHeight * 0.12,
                                        width: kHeight * 0.12,
                                        decoration:
                                        BoxDecoration(
                                          color: kAppColor
                                              .withOpacity(
                                              .02),
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              12),
                                        ),
                                      ),
                                  errorWidget: (context,
                                      url, error) =>
                                      Container(
                                        height:
                                        kHeight * 0.12,
                                        width: kHeight * 0.12,
                                        decoration:
                                        BoxDecoration(
                                          color: Colors
                                              .transparent,
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              12),
                                        ),
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 40,
                                          color: kAppColor
                                              .withOpacity(
                                              .2),
                                        ),
                                      ),
                                )
                            ],
                          ),
                          title: Text(
                            '${post['user']['name']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                _formatTime(post['created_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.public,
                                  size: 12,
                                  color: Colors.grey.shade600),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_horiz,
                                color: Colors.grey.shade700),
                            onPressed: () {},
                          ),
                        ),

                        // Post Title/Caption
                        if (post['title'] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Text(
                              '${post['title']}',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87),
                            ),
                          ),

                        // Images - Facebook Style
                        buildFacebookImageGrid(
                            images, kHeight, context),

                        // Reaction Count Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (post['like_count'] !=
                                      null &&
                                      post['like_count'] >
                                          0) ...[
                                    Text('👍',
                                        style: TextStyle(
                                            fontSize: 14)),
                                    Text('❤️',
                                        style: TextStyle(
                                            fontSize: 14)),
                                    Text('😆',
                                        style: TextStyle(
                                            fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text(
                                      '${post['like_count'] ?? 0}',
                                      style: TextStyle(
                                          color: Colors
                                              .grey.shade700,
                                          fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                ('${post['comments']?.length ?? 0} comments').appTr,
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        Divider(height: 1, thickness: 1),

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                            children: [
                              // Like/Reaction Button
                              Expanded(
                                child: Obx(() {
                                  final post = momentsController
                                      .postList[
                                  postIndex]; // IMPORTANT!!

                                  String currentReaction =
                                  post['like'] == 'yes'
                                      ? (post['reaction'] ??
                                      'like')
                                      : 'none';

                                  return TextButton.icon(
                                    onPressed: () {
                                      _showReactionPicker(
                                          context,
                                          postIndex,
                                          momentsController);
                                    },
                                    onLongPress: () {
                                      _showReactionPicker(
                                          context,
                                          postIndex,
                                          momentsController);
                                    },
                                    icon: Icon(
                                      _getReactionIcon(
                                          currentReaction),
                                      size: 22,
                                      color: _getReactionColor(
                                          currentReaction),
                                    ),
                                    label: Text(
                                      _getReactionText(
                                          currentReaction),
                                      style: TextStyle(
                                        color: _getReactionColor(
                                            currentReaction),
                                        fontSize: 14,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              // Comment Button
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () {
                                    _openCommentSheet(
                                        context, postIndex);
                                  },
                                  icon: Icon(
                                      Icons.chat_bubble_outline,
                                      size: 22,
                                      color:
                                      Colors.grey.shade700),
                                  label: Text(
                                    ('Comment').appTr,
                                    style: TextStyle(
                                      color:
                                      Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // Share Button
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () {},
                                  icon: Icon(
                                      Icons.share_outlined,
                                      size: 22,
                                      color:
                                      Colors.grey.shade700),
                                  label: Text(
                                    ('Share').appTr,
                                    style: TextStyle(
                                      color:
                                      Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          )
        ],
      ),
    );
  }
}

// Image Grid Widget - Facebook Style
Widget buildFacebookImageGrid(
    List<String> images,
    double kHeight,
    BuildContext context,
    ) {
  if (images.isEmpty) return SizedBox.shrink();



  // ---------------- SINGLE IMAGE ----------------
  if (images.length == 1) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: ImageHelper.getImageUrl(images[0]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: kHeight * 0.4,
        ),
      ),
    );
  }

  // ---------------- TWO IMAGES ----------------
  if (images.length == 2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(

              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(images[0]),
                  fit: BoxFit.cover,
                  height: kHeight * 0.25,
                ),
              ),
            ),
          ),
          SizedBox(width: 2),
          Expanded(
            child: GestureDetector(

              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(images[1]),
                  fit: BoxFit.cover,
                  height: kHeight * 0.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- THREE IMAGES ----------------
  if (images.length == 3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(

              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(images[0]),
                  fit: BoxFit.cover,
                  height: kHeight * 0.3,
                ),
              ),
            ),
          ),
          SizedBox(width: 2),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                GestureDetector(

                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(images[1]),
                      fit: BoxFit.cover,
                      height: (kHeight * 0.3 - 2) / 2,
                    ),
                  ),
                ),
                SizedBox(height: 2),
                GestureDetector(

                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(images[2]),
                      fit: BoxFit.cover,
                      height: (kHeight * 0.3 - 2) / 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- FOUR OR MORE IMAGES ----------------
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(

                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(images[0]),
                    fit: BoxFit.cover,
                    height: kHeight * 0.2,
                  ),
                ),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(

                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(images[1]),
                    fit: BoxFit.cover,
                    height: kHeight * 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: GestureDetector(

                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(images[2]),
                    fit: BoxFit.cover,
                    height: kHeight * 0.2,
                  ),
                ),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(

                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: ImageHelper.getImageUrl(images[3]),
                        fit: BoxFit.cover,
                        height: kHeight * 0.2,
                      ),
                    ),
                    if (images.length > 4)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+${images.length - 4}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Facebook-Style Reaction Button
Widget buildFacebookReactions(
    BuildContext context,
    int postIndex,
    var momentsController,
    AnimationController? animationController,
    ) {
  return Obx(() {
    String reactionType =
        momentsController.postList[postIndex]['reaction'] ?? 'none';

    return GestureDetector(
      onTap: () {
        // Show reaction picker
        _showReactionPicker(context, postIndex, momentsController);
      },
      onLongPress: () {
        // Show reaction picker on long press
        _showReactionPicker(context, postIndex, momentsController);
      },
      child: Row(
        children: [
          Icon(
            _getReactionIcon(reactionType),
            size: 28,
            color: _getReactionColor(reactionType),
          ),
          SizedBox(width: 8),
          Text(
            _getReactionText(reactionType),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getReactionColor(reactionType),
            ),
          ),
        ],
      ),
    );
  });
}

// Reaction Picker Dialog
void _showReactionPicker(
    BuildContext context, int postIndex, MomentsController momentsController) {
  showDialog(
    context: context,
    barrierColor: Colors.black12,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _reactionButton(
                  '👍', 'like', postIndex, context, momentsController),
              _reactionButton(
                  '❤️', 'love', postIndex, context, momentsController),
              _reactionButton(
                  '😆', 'haha', postIndex, context, momentsController),
              _reactionButton(
                  '😮', 'wow', postIndex, context, momentsController),
              _reactionButton(
                  '😢', 'sad', postIndex, context, momentsController),
              _reactionButton(
                  '😡', 'angry', postIndex, context, momentsController),
            ],
          ),
        ),
      );
    },
  );
}

Widget _reactionButton(
    String emoji,
    String type,
    int postIndex,
    BuildContext context,
    MomentsController controller,
    ) {
  return GestureDetector(
    onTap: () {
      controller.postList[postIndex]['reaction'] = type;
      controller.postList.refresh();

      controller.reactionCreate(
        postId: controller.postList[postIndex]['id'].toString(),
        reactionType: type,
      );

      Navigator.pop(context);
    },
    child: Container(
      padding: EdgeInsets.all(8),
      child: Text(
        emoji,
        style: TextStyle(fontSize: 32),
      ),
    ),
  );
}

IconData _getReactionIcon(String reaction) {
  switch (reaction) {
    case 'like':
      return Icons.thumb_up;
    case 'love':
      return Icons.favorite;
    case 'haha':
    case 'wow':
    case 'sad':
    case 'angry':
      return Icons.emoji_emotions;
    default:
      return Icons.thumb_up_outlined;
  }
}

Color _getReactionColor(String reaction) {
  switch (reaction) {
    case 'like':
      return Colors.blue;
    case 'love':
      return Colors.red;
    case 'haha':
      return Colors.yellow.shade700;
    case 'wow':
      return Colors.yellow.shade700;
    case 'sad':
      return Colors.yellow.shade700;
    case 'angry':
      return Colors.orange;
    default:
      return Colors.grey.shade600;
  }
}

String _getReactionText(String reaction) {
  switch (reaction) {
    case 'like':
      return ('Like').appTr;
    case 'love':
      return 'Love';
    case 'haha':
      return 'Haha';
    case 'wow':
      return 'Wow';
    case 'sad':
      return 'Sad';
    case 'angry':
      return 'Angry';
    default:
      return ('Like').appTr;
  }
}

// Complete Post Card Widget
Widget buildFacebookPostCard(
    BuildContext context,
    int postIndex,
    var momentsController,
    var authController,
    double kHeight,
    Map<int, AnimationController> animationControllers,
    TickerProvider vsync,
    ) {
  final post = momentsController.postList[postIndex];
  List<String> images = [];

  if (post['post'] != null && post['post'].toString().isNotEmpty) {
    images = List<String>.from(jsonDecode(post['post']));
  }

  return Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        top: BorderSide(color: Colors.grey.shade300, width: 1),
        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(
                      "${post['user']['profile_image']}",
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Frame logic here...
            ],
          ),
          title: Text(
            '${post['user']['name']}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
          subtitle: Text(
            ('Just now').appTr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_horiz, color: Colors.grey.shade700),
            onPressed: () {},
          ),
        ),

        // Post Title/Caption
        if (post['title'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${post['title']}',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),

        // Images - Facebook Style
        buildFacebookImageGrid(images, kHeight, context),

        // Reaction Count Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('👍', style: TextStyle(fontSize: 16)),
                  Text('❤️', style: TextStyle(fontSize: 16)),
                  Text('😆', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text(
                    '${post['like_count'] ?? 0}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
              Text(
                ('${post['comments']?.length ?? 0} comments • ${post['share_count'] ?? 0} shares').appTr,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Like Button
              Expanded(
                child: buildFacebookReactions(
                  context,
                  postIndex,
                  momentsController,
                  animationControllers[postIndex],
                ),
              ),

              // Comment Button
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // Open comment bottom sheet
                  },
                  icon: Icon(Icons.chat_bubble_outline,
                      size: 22, color: Colors.grey.shade700),
                  label: Text(
                    ('Comment').appTr,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              // Share Button
              Expanded(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.share_outlined,
                      size: 22, color: Colors.grey.shade700),
                  label: Text(
                    ('Share').appTr,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _openCommentSheet(BuildContext context, int postIndex) {
  Get.bottomSheet(
    Container(
      height: Get.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ("Comments").appTr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${momentsController.postList[postIndex]['comments']?.length ?? 0}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1),

          // Comments List
          Expanded(
            child: Obx(() {
              final comments =
                  momentsController.postList[postIndex]['comments'] ?? [];

              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 60, color: Colors.grey.shade300),
                      SizedBox(height: 10),
                      Text(
                        ('No comments yet').appTr,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        ('Be the first to comment').appTr,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Picture
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(
                                      "${comments[index]['user']['profile_image']}"),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (comments[index]['user']
                            ['asset_purchase_history'] !=
                                null &&
                                comments[index]['user']
                                ['asset_purchase_history']['asset'] !=
                                    null)
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      ImageHelper.getImageUrl(
                                          "${comments[index]['user']['asset_purchase_history']['asset']['asset']}"),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),

                        // Comment Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${comments[index]['user']['name']}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "${comments[index]['comment']}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    ('Just now').appTr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(width: 15),
                                  Text(
                                    ('Like').appTr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(width: 15),
                                  Text(
                                    ('Reply').appTr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),

          // Comment Input Box
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                // User Profile Picture
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(
                    ImageHelper.getImageUrl(
                        "${authController.userProfile.value.user?.profileImage ?? "default.png"}"),
                  ),
                ),
                const SizedBox(width: 10),

                // Text Field
                Expanded(
                  child: TextField(
                    controller: momentsController.comment,
                    decoration: InputDecoration(
                      hintText: ("Write a comment...").appTr,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xff8A4CF7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      if (momentsController.comment.text.trim().isNotEmpty) {
                        momentsController.commentCreate(
                          postId: momentsController.postList[postIndex]['id']
                              .toString(),
                          postIndex: postIndex,
                        );
                      }
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
  );
}

String _formatTime(String timeString) {
  try {
    DateTime dateTime = DateTime.parse(timeString);
    return DateFormat('hh:mm a').format(dateTime);
    // Example output: 05:32 PM
  } catch (e) {
    return timeString;
  }
}
