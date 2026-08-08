import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';


import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/constants.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../../../widgets/after/CastomText.dart';
import '../../../../../widgets/after/castom appbar.dart';
import '../../../informationcollection/controllers/informationcollection_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AgencyHostRequestList extends StatelessWidget {
  const AgencyHostRequestList({super.key});

  @override
  Widget build(BuildContext context) {
    InformationcollectionController informationcollectionController =
        Get.put(InformationcollectionController());
    final agencjNewData = Get.arguments;

    informationcollectionController.showAgencyHostList(
      agencyId: int.parse(agencjNewData['agency_id'].toString()),
    );
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Agency Request List').appTr,
      ),
      body: Obx(() {
        return ListView.builder(
          itemCount: informationcollectionController.newAgencyhostList.length,
          itemBuilder: (BuildContext context, int index) {
            final agencyData =
                informationcollectionController.newAgencyhostList[index];
            print('Host List $agencyData');
            return GestureDetector(
              onTap: () {
                // verifiedController.agencyJoinPost(
                //     userId: selectedUser!['user_id']);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey[100],
                ),
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "$kDomainUrl/${agencyData['profile_image']}",
                          imageBuilder: (context, imageProvider) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTD8qrkPg5tffSPQIqlxXcW-czht693ZlfJnHGej1zZUVvStsw638N4108&s',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Castontext(
                              fontSize: Get.height * 0.016,
                              fontWeight: FontWeight.w600,
                              textColor: Colors.black.withOpacity(.6),
                              text: ('ID: ${agencyData['id']}').appTr,
                            ),
                            const SizedBox(height: 5),
                            Castontext(
                              fontSize: Get.height * 0.015,
                              fontWeight: FontWeight.w400,
                              textColor: Colors.black.withOpacity(.6),
                              text: ('Name: ${agencyData['name'] ?? 'N/A'}').appTr,
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        homeController.visitProfile(
                            userId: agencyData['id'].toString());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 4, horizontal: kWeight * 0.02),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xff8A4CF7),
                              Color(0xffB460F0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text(
                            ('Details').appTr,
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: kHeight * 0.014,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
