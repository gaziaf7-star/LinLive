import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/color_constants.dart'
    show kAppColor, kPrimaryColor;
import '../../../../../constants/constants.dart';
import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../../../widgets/after/CastomText.dart';
import '../../controllers/moments_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class createPostView extends GetView<MomentsController> {
  const createPostView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
            style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                backgroundColor: Colors.grey[200]),
            onPressed: () {
              Get.back();
            },
            icon: Icon(CupertinoIcons.back,
                size: 23, color: Colors.black.withOpacity(.7))),
        centerTitle: true,
        title: Text(
          ('Create post').appTr,
          style: GoogleFonts.roboto(
            fontSize: 17,
            color: Colors.black.withOpacity(.6),
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              child: TextButton(
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    backgroundColor: kAppColor),
                onPressed: () {},
                child: Text(
                  ('POST').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //body part friends start
              Row(
                children: [
                  Obx(() {
                    final frameData =
                        homeController.activeFrameData['active_asset_ids'];
                    final profileImage =
                        authController.userProfile.value.user?.profileImage;

                    // Safe convert
                    final agencyIdRaw =
                        authController.userProfile.value.user?.agencyId;
                    final int agencyId =
                        int.tryParse(agencyIdRaw?.toString() ?? '0') ?? 0;

                    return SizedBox(
                      height: kHeight * 0.07,
                      width: kHeight * 0.07,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // ---------------- PROFILE IMAGE ----------------
                          CircleAvatar(
                            radius: kHeight * 0.083,
                            backgroundColor: Colors.transparent,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: CachedNetworkImage(
                                imageUrl: ImageHelper.getImageUrl(profileImage),
                                fit: BoxFit.cover,
                                height: kHeight * 0.05,
                                width: kHeight * 0.05,
                                placeholder: (context, url) => Container(
                                  height: kHeight * 0.05,
                                  width: kHeight * 0.05,
                                  color: kAppColor.withOpacity(.2),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person,
                                  size: 40,
                                  color: kAppColor.withOpacity(.2),
                                ),
                              ),
                            ),
                          ),

                          // ---------------- AGENCY FRAME (if agencyId > 0) ----------------


                          // ---------------- NORMAL FRAME (if no agency frame) --------------
                           if (frameData != null &&
                              frameData['asset'] != null &&
                              frameData['asset']['asset'] != null)
                            // Check if the asset path ends with .svga
                            (frameData['asset']['asset']
                                    .toString()
                                    .endsWith('.svga'))
                                ? SizedBox(
                                    height: kHeight * 0.1,
                                    width: kHeight * 0.1,
                                    child: SVGAEasyPlayer(
                                      resUrl:
                                          '$kDomainUrl/${frameData['asset']['asset']}',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl:
                                        "$kDomainUrl/${frameData['asset']['asset']}",
                                    height: kHeight * 0.1,
                                    width: kHeight * 0.1,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: kHeight * 0.12,
                                      width: kHeight * 0.12,
                                      decoration: BoxDecoration(
                                        color: kAppColor.withOpacity(.02),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: kHeight * 0.12,
                                      width: kHeight * 0.12,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: kAppColor.withOpacity(.2),
                                      ),
                                    ),
                                  )

                          // ---------------- NOTHING (no frame) ----------------
                          else
                            SizedBox(
                              height: kHeight * 0.02,
                              width: kHeight * 0.02,
                            ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${authController.userProfile.value.user!.name}',
                        style: GoogleFonts.poppins(
                          color: Colors.black.withOpacity(.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 3),
                      Castontext(
                          textColor: Colors.black.withOpacity(.7),
                          text:
                              ('Phone : ${authController.userProfile.value.user!.phone}').appTr)
                    ],
                  ),
                ],
              ),

              // body part text fild what's on your mind ?
              SizedBox(height: 30),
              Container(
                height: Get.height * 0.15, // status box motamuti 3 line
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Colors.white,
                ),
                child: TextFormField(
                  controller: controller.titleController,
                  minLines: 2,
                  maxLines: null, // unlimited line
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.roboto(
                        fontWeight: FontWeight.w400,
                        color: Colors.black.withOpacity(.6),
                        fontSize: kHeight * 0.023),
                    hintText: ("What's on your mind?").appTr,
                  ),
                ),
              ),

              SizedBox(height: 10),
              Obx(
                () => controller.allPickedImage.isEmpty
                    ? Container()
                    : Container(
                        height: 300,
                        width: 300,
                        child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 images per row
                            crossAxisSpacing: 8, // Space between columns
                            mainAxisSpacing: 8, // Space between rows
                          ),
                          itemCount: controller.allPickedImage.length,
                          itemBuilder: (context, index) {
                            return Image.file(
                              File(controller.allPickedImage[index]),
                              height: Get.height * 0.3,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  controller.allFilePicker();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 7),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                      border: Border.all(color: Colors.white.withOpacity(.6))),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image,
                        color: kAppColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Castontext(
                          fontWeight: FontWeight.w400,
                          fontSize: kHeight * 0.016,
                          textColor: Colors.black.withOpacity(.5),
                          text: ('Photo/video').appTr)
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40),
              Center(
                child: Obx(() {
                  return InkWell(
                    onTap: () {
                      if (!controller.isLoading.value) {
                        controller.postCreate();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      alignment: Alignment.center,
                      width: controller.isLoading.value ? 50 : Get.width * 0.5,
                      height: 50,
                      padding: EdgeInsets.symmetric(
                        vertical: controller.isLoading.value ? 0 : 15,
                        horizontal: controller.isLoading.value ? 0 : 20,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            controller.isLoading.value ? 50 : 13),
                        color: kAppColor,
                      ),
                      child: controller.isLoading.value
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : Text(
                              ('Post Now').appTr,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Group_text_icon extends StatelessWidget {
  final String text;
  final IconData icon;

  const Group_text_icon({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 15),
          SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.akatab(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_outlined, color: Colors.white, size: 15),
        ],
      ),
    );
  }
}
