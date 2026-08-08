import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/setheight.dart';

import '../../store/controllers/store1_controller.dart';
import '../controllers/store_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Backpackfolowrlist extends StatelessWidget {
  const Backpackfolowrlist({super.key});

  @override
  Widget build(BuildContext context) {
    Store1Controller store1controller = Get.put(Store1Controller());
    StoreController storeController = Get.put(StoreController());
    return Scaffold(
      body: Column(
        children: [
          SetHeight(heightSet: 0.02),
          Container(
            margin: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: Colors.grey[100],
            ),
            height: 40,
            child: TextFormField(
              onChanged: (value) {
                store1controller.searchByUserId(value);
              },
              decoration: InputDecoration(
                hintText: ("Search by User ID...").appTr,
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SetHeight(heightSet: 0.01),
          Expanded(
            child: FutureBuilder(
              future: store1controller.showFollowerList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    itemCount: store1controller.followerList.length,
                    itemBuilder: (context, index) {
                      return Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: EdgeInsets.all(kHeight * 0.012),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Container(
                              height: 12,
                              width: 120,
                              color: Colors.grey,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 6),
                                Container(
                                  height: 10,
                                  width: 160,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 10,
                                  width: 100,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            trailing: Container(
                              height: 14,
                              width: 60,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                // 🔹 Error State
                if (snapshot.hasError) {
                  return Center(child: Text(("Error: ${snapshot.error}").appTr));
                }

                // 🔹 Empty State
                if (store1controller.followerList.isEmpty) {
                  return Center(child: Text(("No followers found").appTr));
                }

                // 🔹 Real Data
                return ListView.builder(
                  itemCount: store1controller.followerList.length,
                  itemBuilder: (BuildContext context, int index) {
                    var follower = store1controller.followerList[index];
                    return GestureDetector(
                      onTap: () {
                        storeController.sendingAssetBackPack(
                            userId: follower['user']['user_id'].toString());
                      },
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.all(kHeight * 0.012),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: follower['user']['profile_image'] !=
                                          null &&
                                      follower['user']['profile_image']
                                          .toString()
                                          .isNotEmpty
                                  ? '$kMainUrl/${follower['user']['profile_image']}'
                                  : 'https://ui-avatars.com/api/?name=${follower['user']['name'] ?? "User"}',
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.account_circle,
                                size: 40,
                                color: Colors.grey,
                              ),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            ('Uid : ${follower['user']['user_id'].toString()}').appTr,
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w600,
                              fontSize: kHeight * 0.016,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ('Name : ${follower['user']['name']}').appTr,
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.w500,
                                  fontSize: kHeight * 0.012,
                                ),
                              ),
                              Text(
                                '${follower['user']['user_type']}',
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.w500,
                                  fontSize: kHeight * 0.012,
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 0, horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: follower['user']['is_online'] == 'true'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 3.0),
                              child: Castontext(
                                fontWeight: FontWeight.w400,
                                fontSize: kHeight * 0.013,
                                textColor: Color(0xffffffff),
                                text: follower['user']['is_online'] == 'true'
                                    ? ('Online').appTr: ('Offline').appTr,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
