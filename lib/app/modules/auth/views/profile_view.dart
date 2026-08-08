import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomProfile.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/buildIconbutton.dart';
import '../../appmenu/views/widgets/game_test.dart';
import '../../messanger/views/messanger_view.dart';

import '../../myprofile/controllers/myprofile_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  MyprofileController myprofileController = Get.put(MyprofileController());
  @override
  Widget build(BuildContext context) {
    final data = Get.arguments;
    print('response data ${data['User Data']}');
    return SafeArea(
      bottom: true,
      child: Scaffold(
        body: DefaultTabController(
          length: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                //user cover image  show bottom sheet
                Container(
                  height: Get.height * 0.4,
                  decoration: BoxDecoration(
                    image: (data['User Data'] == null ||
                            data['User Data'] == "" ||
                            data['User Data'] == "No Photo")
                        ? DecorationImage(
                            image: AssetImage('assets/images/profile pic.jpg'),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: NetworkImage(
                              '$kDomainUrl/${data['User Data']['cover_images']}',
                            ),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 25),
                          child: topIconbutton(
                            onPressed: () {
                              Get.back();
                            },
                            icon: const Icon(Icons.arrow_back_ios_new_outlined),
                            colour: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0, top: 25),
                          child: topIconbutton(
                            onPressed: () {
                              livestreamController.isBroadcaster.value
                                  ? null
                                  : Get.bottomSheet(
                                      Container(
                                        decoration: BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                                topRight: Radius.circular(20),
                                                topLeft: Radius.circular(20)),
                                            color: Colors.white),
                                        height: Get.height * 0.37,
                                        width: double.infinity,
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              height: 20,
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                Get.defaultDialog(
                                                    backgroundColor:
                                                        Color(0xffffffff));
                                              },
                                              child:
                                                  CastomUserProfileotherOption(
                                                text: ('Remark').appTr,
                                              ),
                                            ),
                                            CastomUserProfiledevider(),
                                            CastomUserProfileotherOption(
                                              text: ('Report').appTr,
                                            ),
                                            CastomUserProfiledevider(),
                                            CastomUserProfileotherOption(
                                              text: ('Follow').appTr,
                                            ),
                                            CastomUserProfiledevider(),
                                            CastomUserProfileotherOption(
                                              text: ('Block').appTr,
                                            ),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  color: Color(0xfff3f3f5)),
                                            ),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                Get.back();
                                              },
                                              child:
                                                  CastomUserProfileotherOption(
                                                text: ('Cancel').appTr,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                            },
                            icon: const Icon(Icons.dehaze),
                            colour: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                //----------------profile -------------------
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(20),
                          topLeft: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          //tap bar start
                          if (data['User Data']['asset_purchase_history'] !=
                                  null &&
                              data['User Data']['asset_purchase_history']
                                      ['asset'] !=
                                  null &&
                              data['User Data']['asset_purchase_history']
                                      ['asset']['asset'] !=
                                  null)
                            SizedBox(height: kHeight * 0.055),

                          // ---------------------level identity -------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 🔹 User ID Text
                              Text(
                                ('UID ${data?['User Data']?['user_id']}').appTr,
                                style: GoogleFonts.roboto(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),

                              // 🔹 Copy Icon
                              GestureDetector(
                                onTap: () {
                                  final id = "${data['User Data']['id']}";
                                  Clipboard.setData(ClipboardData(text: id));

                                  // Feedback message
                                  Fluttertoast.showToast(
                                    msg: ("User ID copied to clipboard").appTr,
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.black87,
                                    textColor: Colors.white,
                                    fontSize: 16.0,
                                  );
                                },
                                child: Icon(
                                  Icons.copy,
                                  size: 20,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: kHeight * 0.005),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ' ${data['User Data']?['name'] ?? ''}',
                                style: GoogleFonts.merriweather(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width: kWeight * 0.02,
                              ),
                              LevelFrame(
                                level: '${data['User Data']['level'] ?? ''}',
                              ),
                            ],
                          ),
                          SizedBox(height: kHeight * 0.012),

                          livestreamController.isBroadcaster.value
                              ? Container()
                              : Center(
                                  child: InkWell(
                                    onTap: () {
                                      momentsController.followCreate(
                                          userId:
                                              '${authController.userProfile.value.user!.id}');
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.only(right: 20),
                                      height: 29,
                                      width: 80,
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(50),
                                        ),
                                        color: kAppColor,
                                      ),
                                      child: Text(
                                        ('Follow').appTr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          SizedBox(height: kHeight * 0.01),
                          Row(
                            children: [
                              SizedBox(width: 15),
                              Text(
                                ('Identity Symbol').appTr,
                                style: GoogleFonts.roboto(
                                  fontSize: kHeight * 0.018,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: kHeight * 0.012),
                          Row(
                            children: [
                              SizedBox(
                                  width: kWeight * 0.03), // ≈ 15px responsive

                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    height: kHeight *
                                        0.04, // slightly bigger for visibility
                                    width: kWeight * 0.25,
                                    decoration: BoxDecoration(
                                      image: const DecorationImage(
                                        image: AssetImage(
                                            'assets/icons/gurdeep-singh-T2Rx7-ZtgKw-unsplash.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(kHeight * 0.05),
                                      border: Border.all(
                                        color: const Color(0xffefa567),
                                        width: kHeight *
                                            0.002, // responsive border width
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: kWeight * 0.08),
                                        Flexible(
                                          child: Text(
                                            '${data['User Data']['user_type'] ?? ''}',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.lato(
                                              fontSize: kHeight *
                                                  0.018, // responsive text
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xfff1bc0d),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -kHeight * 0.002,
                                    left: -kHeight * 0.008,
                                    child: (homeController.activeFrameData[
                                                    'active_asset_ids'] !=
                                                null &&
                                            homeController.activeFrameData[
                                                        'active_asset_ids']
                                                    ['asset'] !=
                                                null &&
                                            homeController.activeFrameData[
                                                        'active_asset_ids']
                                                    ['asset']['asset'] !=
                                                null)
                                        ? CachedNetworkImage(
                                            imageUrl: ImageHelper.getImageUrl(
                                                "${homeController.activeFrameData['active_asset_ids']['asset']['asset']}"),
                                            height: kHeight * 0.045,
                                            width: kHeight * 0.045,
                                            fit: BoxFit.cover,
                                          )
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: kHeight * 0.01),

                          Row(
                            children: [
                              SizedBox(width: 15),
                              Text(
                                ('Gifts - Received').appTr,
                                style: GoogleFonts.roboto(
                                  fontSize: kHeight * 0.018,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 25),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18.0),
                            child: data['User Data']['receive_gift_list'] ==
                                        null ||
                                    data['User Data']['receive_gift_list']
                                        .isEmpty
                                ? Center(
                                    child: Text(
                                      ("No gifts received yet 🎁").appTr,
                                      style: GoogleFonts.roboto(
                                        color: kAppColor,
                                        fontSize: kHeight * 0.018,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      mainAxisExtent: kHeight * 0.11,
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.7,
                                    ),
                                    itemCount: data['User Data']
                                            ['receive_gift_list']
                                        .length,
                                    itemBuilder: (context, receiverIndex) {
                                      final receiverGift = data['User Data']
                                          ['receive_gift_list'][receiverIndex];
                                      print('User Receiver gift $receiverGift');
                                      return Container(
                                        height: 110,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0x85c7a2f4),
                                              Color(0xca8c6af0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: Color(0x85461dd6),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(height: 2),
                                            receiverGift['gift']['show_image']
                                                    .toString()
                                                    .endsWith('.svga')
                                                ? SizedBox(
                                                    height: kHeight * 0.05,
                                                    width: kHeight * 0.05,
                                                    child: SVGAEasyPlayer(
                                                      resUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${receiverGift['gift']['show_image']}',
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: CachedNetworkImage(
                                                      imageUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${receiverGift['gift']['show_image']}',
                                                      ),
                                                      height: kHeight * 0.05,
                                                      width: kHeight * 0.05,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                            Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8.0,
                                                          bottom: 8,
                                                          right: 5),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                    child: CachedNetworkImage(
                                                      imageUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${receiverGift['sender']['profile_image']}',
                                                      ),
                                                      height: kHeight * 0.025,
                                                      width: kHeight * 0.025,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8.0),
                                                  child: Castontext(
                                                    textColor: Colors.white,
                                                    fontSize: kHeight * 0.011,
                                                    fontWeight: FontWeight.w500,
                                                    text:
                                                        '${receiverGift['sender']['name']}',
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 18.0),
                                child: Text(
                                  ('Gifts - Sent').appTr,
                                  style: GoogleFonts.roboto(
                                    fontSize: kHeight * 0.018,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),

                          ///------------------  Gift sent -----------

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18.0),
                            child: data['User Data']['send_gift_list'] ==
                                        null ||
                                    data['User Data']['send_gift_list'].isEmpty
                                ? Center(
                                    child: Text(
                                      ("No gifts sent yet 🎁").appTr,
                                      style: GoogleFonts.roboto(
                                        color: kAppColor,
                                        fontSize: kHeight * 0.018,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      mainAxisExtent: kHeight * 0.11,
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.7,
                                    ),
                                    itemCount: data['User Data']
                                            ['send_gift_list']
                                        .length,
                                    itemBuilder: (context, index) {
                                      final sentGift =
                                          data['User Data']['send_gift_list'];
                                      return Container(
                                        height: 110,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0x85c7a2f4),
                                              Color(0xca8c6af0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: Color(0x85461dd6),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(height: 2),
                                            sentGift[index]['gift']
                                                        ['show_image']
                                                    .toString()
                                                    .endsWith('.svga')
                                                ? SizedBox(
                                                    height: kHeight * 0.05,
                                                    width: kHeight * 0.05,
                                                    child: SVGAEasyPlayer(
                                                      resUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${sentGift[index]['gift']['show_image']}',
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: CachedNetworkImage(
                                                      imageUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${sentGift[index]['gift']['gift_image']}',
                                                      ),
                                                      height: kHeight * 0.05,
                                                      width: kHeight * 0.05,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                            Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8.0,
                                                          bottom: 8,
                                                          right: 5),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                    child: CachedNetworkImage(
                                                      imageUrl: ImageHelper
                                                          .getImageUrl(
                                                        '${sentGift[index]['receiver']['profile_image']}',
                                                      ),
                                                      height: kHeight * 0.025,
                                                      width: kHeight * 0.025,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8.0),
                                                  child: Castontext(
                                                    textColor: Colors.white,
                                                    fontSize: kHeight * 0.011,
                                                    fontWeight: FontWeight.w500,
                                                    text:
                                                        '${sentGift[index]['receiver']['name']}',
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          SizedBox(height: 15),
                        ], //fast row end
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -kHeight * 0.05,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 🔴 Agency Frame (যদি agency_id != 0)
                          // if (data['User Data']?['agency_id'] != null &&
                          //     data['User Data']['agency_id'] != 0)
                          //   SizedBox(
                          //     height: kHeight * 0.11,
                          //     width: kHeight * 0.11,
                          //     child: SVGAEasyPlayer(
                          //       assetsName: agencyFrame,
                          //       fit: BoxFit.cover,
                          //     ),
                          //   )
                          Align(
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: kHeight * 0.035,
                              backgroundColor: Colors.transparent,
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(
                                    "${data['User Data']['profile_image']}",
                                  ),
                                  fit: BoxFit.cover,
                                  height: kHeight * 0.07,
                                  width: kHeight * 0.07,
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.person, size: kHeight * 0.07),
                                  placeholder: (context, url) => SizedBox(
                                    height: kHeight * 0.07,
                                    width: kHeight * 0.07,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 🟡 Asset Frame (যদি agency না থাকে এবং asset_purchase_history থাকে)
                          if (data['User Data']?['asset_purchase_history'] !=
                                  null &&
                              data['User Data']['asset_purchase_history']
                                      ?['asset']?['asset'] !=
                                  null)
                            (data['User Data']['asset_purchase_history']
                                        ['asset']['asset']
                                    .toString()
                                    .endsWith('.svga'))
                                ? SizedBox(
                                    height: kHeight * 0.11,
                                    width: kHeight * 0.11,
                                    child: SVGAEasyPlayer(
                                      resUrl: ImageHelper.getImageUrl(
                                          data['User Data']
                                                  ['asset_purchase_history']
                                              ['asset']['asset']),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: ImageHelper.getImageUrl(
                                      "${data['User Data']['asset_purchase_history']['asset']['asset']}",
                                    ),
                                    height: kHeight * 0.11,
                                    width: kHeight * 0.11,
                                    fit: BoxFit.cover,
                                  ),

                          // 🟢 Profile Image (সবসময় থাকবে)
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        ///------------------ bottom part -------------
        bottomNavigationBar: data?['User Data']?['user_id'] ==
                authController.userProfile.value.user?.userId
            ? Container(
                margin: EdgeInsets.all(kHeight * 0.02),
                height: kHeight * 0.06,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xfffa5f0b),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: InkWell(
                          onTap: () {
                            Get.to(MessengerView(),
                                transition: Transition.rightToLeft);
                          },
                          child: Container(
                            decoration: BoxDecoration(),
                            child: Castontext(
                                textColor: Colors.white,
                                fontSize: kHeight * 0.015,
                                text: ('Go to chat').appTr),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 6,
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kAppColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: InkWell(
                          onTap: () {
                            Get.bottomSheet(
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(30),
                                    topRight: Radius.circular(30),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Premium Custom Painted Header
                                    CustomPaint(
                                      painter: HeaderPainter(),
                                      child: Container(
                                        height: kHeight * 0.12,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 24),
                                        width: double.infinity,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  ("Guest Living").appTr,
                                                  style: TextStyle(
                                                    fontFamily: "Roboto",
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.25),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        ("0 Members").appTr,
                                                        style: TextStyle(
                                                          fontFamily: "Roboto",
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 35),

                                    // Premium Center Content
                                    Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.redAccent
                                                    .withOpacity(0.2),
                                                Colors.orange.withOpacity(0.2)
                                              ],
                                            ),
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.redAccent,
                                                  Colors.orange
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.redAccent
                                                      .withOpacity(0.4),
                                                  blurRadius: 20,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.mic,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          ("Start Living with Host").appTr,
                                          style: TextStyle(
                                            fontFamily: "Roboto",
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ("Choose your preferred mode").appTr,
                                          style: TextStyle(
                                            fontFamily: "Roboto",
                                            fontSize: 13,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 35),

                                    // Premium Buttons
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 24),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Video Living Button
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                // Video living action
                                              },
                                              child: Container(
                                                height: 54,
                                                margin: const EdgeInsets.only(
                                                    right: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFFFF5F6D),
                                                      Color(0xFFFFC371)
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFFFF5F6D)
                                                          .withOpacity(0.4),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.videocam_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      ("Video").appTr,
                                                      style: TextStyle(
                                                        fontFamily: "Roboto",
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Voice Living Button
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                // Voice living action
                                              },
                                              child: Container(
                                                height: 54,
                                                margin: const EdgeInsets.only(
                                                    left: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFF667EEA),
                                                      Color(0xFF764BA2)
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFF667EEA)
                                                          .withOpacity(0.4),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.mic_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      ("Voice").appTr,
                                                      style: TextStyle(
                                                        fontFamily: "Roboto",
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              isScrollControlled: true,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(),
                            child: Castontext(
                                fontSize: kHeight * 0.015,
                                textColor: Colors.white,
                                text: ('Calling').appTr),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox.shrink(),
      ),
    );
  }
}

class HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0xFFFF5F6D),
          Color(0xFFFFC371),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final Path path = Path();

    // Start from top left
    path.moveTo(0, 0);

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge down
    path.lineTo(size.width, size.height - 30);

    // Beautiful curved bottom
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 10,
      size.width * 0.5,
      size.height - 5,
    );

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      0,
      size.height - 30,
    );

    // Left edge back to top
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);

    // Add subtle shadow effect
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
