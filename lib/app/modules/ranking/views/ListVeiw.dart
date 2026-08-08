import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/ranking/views/ranking_view.dart';
import 'package:meetlivepro/app/modules/ranking/views/sendingListShow.dart';


import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/customRankingcode.dart';
import '../../informationcollection/controllers/informationcollection_controller.dart';
import 'hederRanking/FollowButton.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class RankingList extends StatelessWidget {
  const RankingList({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(InformationcollectionController());

    informationcollectionController.showAgencyHostList(
        agencyId:
            int.parse(verifiedController.agencySingleData['agency_id'].toString()));
    return Scaffold(
      backgroundColor: const Color(0xffd0c8fb),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Obx(() {
            return ListView.builder(
              itemCount:
                  informationcollectionController.newAgencyhostList.length,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  final first =
                      informationcollectionController.newAgencyhostList[0];
                  final second =
                      informationcollectionController.newAgencyhostList.length >
                              1
                          ? informationcollectionController.newAgencyhostList[1]
                          : null;
                  final third =
                      informationcollectionController.newAgencyhostList.length >
                              2
                          ? informationcollectionController.newAgencyhostList[2]
                          : null;

                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.0, vertical: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // -------- 2nd Place (Left) --------
                        if (second != null)
                          Column(
                            children: [
                              CastonRankingcard(
                                frame: second['asset_purchase_history'] == null
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(
                                          ImageHelper.getImageUrl(
                                              '${second['asset_purchase_history']['asset']['asset']}'),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                coin: '${second['earned_coins']}',
                                profileImage: ImageHelper.getImageUrl(
                                    '${second['profile_image']}'),
                                pwidth: Get.width * 0.077,
                                fastColor: Color(0xFFe3dce3),
                                secondColor: Color(0xff8A4CF7),
                                height: Get.height * 0.13,
                                width: Get.width * 0.23,
                                bottomColor: Color(0xff8A4CF7),
                                rankText: '2',
                                name: '${second['name']}', backgroundImage: 'assets/new/rankfastcard.png',
                              ),
                              SizedBox(height: kHeight * 0.032),
                              RankinFollowButton(
                                text: ('Follow').appTr,
                                onPressed: () {},
                              )
                            ],
                          ),

                        // -------- 1st Place (Middle) --------
                        Column(
                          children: [
                            CastonRankingcard(
                              frame: first['asset_purchase_history'] == null
                                  ? null
                                  : DecorationImage(
                                      image: NetworkImage(
                                        ImageHelper.getImageUrl(
                                            '${first['asset_purchase_history']['asset']['asset']}'),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                              coin: '${first['earned_coins']}',
                              profileImage: ImageHelper.getImageUrl(
                                  '${first['profile_image']}'),
                              pwidth: Get.width * 0.1,
                              fastColor: Color(0xff8A4CF7),
                              secondColor: Color(0xFFfec42a),
                              height: Get.height * 0.17,
                              width: Get.width * 0.29,
                              bottomColor: Color(0xFFfec42a),
                              rankText: '1',
                              name: '${first['name']}', backgroundImage: 'assets/new/rankfastcard.png',
                            ),
                            SizedBox(height: kHeight * 0.032),
                            RankinFollowButton(
                              text: ('Follow').appTr,
                              onPressed: () {},
                            )
                          ],
                        ),

                        // -------- 3rd Place (Right) --------
                        if (third != null)
                          Column(
                            children: [
                              CastonRankingcard(
                                frame: third['asset_purchase_history'] == null
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(
                                          ImageHelper.getImageUrl(
                                              '${third['asset_purchase_history']['asset']['asset']}'),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                coin: '${third['earned_coins']}',
                                profileImage: ImageHelper.getImageUrl(
                                    '${third['profile_image']}'),
                                pwidth: Get.width * 0.076,
                                fastColor: Color(0xFFfdbca0),
                                secondColor: Color(0xFFff847d),
                                height: Get.height * 0.13,
                                width: Get.width * 0.23,
                                bottomColor: Color(0xFFff847d),
                                rankText: '3',
                                name: '${third['name']}', backgroundImage: 'assets/new/rankfastcard.png',
                              ),
                              SizedBox(height: kHeight * 0.032),
                              RankinFollowButton(
                                text: ('Follow').appTr,
                                onPressed: () {},
                              )
                            ],
                          )
                      ],
                    ),
                  );
                }

                // 🔹 4th থেকে normal card
                if (index >= 3) {
                  final item =
                      informationcollectionController.newAgencyhostList[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff9d67fd), Color(0xffc87efd)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Rank Number
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),

                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Frame Image
                            Container(
                              height: kHeight * 0.045,
                              width: kHeight * 0.045,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: item['asset_purchase_history'] == null
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(
                                          ImageHelper.getImageUrl(
                                              '${item['asset_purchase_history']['asset']['asset']}'),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            // Profile Image
                            Container(
                              height: kHeight * 0.03,
                              width: kHeight * 0.03,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors
                                    .grey.shade200, // placeholder background
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(
                                      "${item['profile_image']}"),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => SizedBox(),
                                  // কোন delay না
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.person),
                                  // error হলে icon
                                  fadeInDuration:
                                      Duration.zero, // fade effect বন্ধ
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Avatar

                        const SizedBox(width: 12),

                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['name']}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              Castontext(
                                  textColor: Colors.yellow,
                                  text: ('Coins :${item['earned_coins']}').appTr)
                            ],
                          ),
                        ),

                        // Points
                        Row(
                          children: [
                            InkWell(
                              onTap: () {},
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 7),
                                decoration: BoxDecoration(
                                    color: Color(0xff8A4CF7),
                                    borderRadius: BorderRadius.circular(50),
                                    border:
                                        Border.all(color: Color(0xff8A4CF7))),
                                child: Text(
                                  ('Follow').appTr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            );
          }),
        ),
      ),
    );
  }
}
