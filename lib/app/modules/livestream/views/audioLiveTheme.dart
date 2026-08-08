import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Audiolivetheme extends StatelessWidget {
  const Audiolivetheme({super.key});

  @override
  Widget build(BuildContext context) {
    LivestreamController livestreamController = Get.find();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // transparent দিতে হবে
        leading: IconButton(
          style:
              IconButton.styleFrom(backgroundColor: kAppColor.withOpacity(.5)),
          onPressed: () {
            livestreamController.showTheme();
          },
          icon: Icon(
            CupertinoIcons.left_chevron,
            size: kHeight * 0.02,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        title: Castontext(
          fontSize: kHeight * 0.017,
          textColor: Colors.white,
          fontWeight: FontWeight.w400,
          text: ('Change Theme').appTr,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xff8A4CF7),
                Color(0xffB460F0).withOpacity(.8),
                kAppColor
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: kHeight * 0.02,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: kWeight * 0.03),
              child: FutureBuilder(
                  future: livestreamController.showTheme(),
                  builder: (context, snapshot) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: livestreamController.themeList.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            livestreamController.createTheme(
                                userId:
                                    '${authController.userProfile.value.user!.id}',
                                themeID: livestreamController.themeList[index]
                                    ['id']);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: kAppColor.withOpacity(.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      ImageHelper.getImageUrl('${livestreamController.themeList[index]['image']}'),
                                  height: kHeight * 0.16,
                                  width: kHeight * 0.12,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
            )
          ],
        ),
      ),
    );
  }
}
