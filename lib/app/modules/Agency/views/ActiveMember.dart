import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/small_text_widgets.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ActiveMember extends StatefulWidget {
  const ActiveMember({super.key});

  @override
  State<ActiveMember> createState() => _ActiveMemberState();
}

class _ActiveMemberState extends State<ActiveMember> {
  // Items and selected value
  final List<String> items = ['January', 'Feb', 'March'];
  String? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = items.first; // Initialize with first item
  }

  @override
  Widget build(BuildContext context) {
    informationcollectionController.showAgencyHostList(
      agencyId: int.parse(
          verifiedController.agencySingleData['agency_id'].toString()),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(Icons.arrow_back_ios_new),
        ),
        centerTitle: true,
        title: Text(('Member active days').appTr),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ('Member').appTr,
                    style: GoogleFonts.lato(
                        fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedValue,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedValue = newValue!;
                          });
                        },
                        items:
                            items.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              return SizedBox(
                height: Get.height * 0.7,
                child: ListView.builder(
                  itemCount:
                      informationcollectionController.newAgencyhostList.length,
                  itemBuilder: (context, index) {
                    final hostdata = informationcollectionController
                        .newAgencyhostList[index];
                    return Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 5, horizontal: kWeight * 0.02),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            color: Colors.grey[100]),
                        height: 70,
                        child: Row(
                          children: [
                            // Host Column
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      image:
                                          hostdata['asset_purchase_history'] ==
                                                  null
                                              ? null
                                              : DecorationImage(
                                                  image: NetworkImage(
                                                    ImageHelper.getImageUrl(
                                                      hostdata[
                                                              'asset_purchase_history']
                                                          ['asset']['asset'],
                                                    ),
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.grey[300],
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: CachedNetworkImage(
                                          imageUrl: ImageHelper.getImageUrl(
                                              hostdata['profile_image']),
                                          fit: BoxFit.cover,
                                          width: 50,
                                          height: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SmallTextStyle(
                                        color: Colors.black,
                                        text: hostdata['name'],
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      SizedBox(
                                        height: kHeight * 0.006,
                                      ),
                                      SmallTextStyle(
                                        color: Colors.black,
                                        text: ('ID: ${hostdata['id'] ?? 0}').appTr,
                                        fontSize: 12,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Total Diamonds

                            // Day

                            // Time
                            Expanded(
                              flex: 2,
                              child: SmallTextStyle(
                                color: Colors.black,
                                text: ('Active').appTr,
                                fontSize: 16,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}
