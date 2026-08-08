import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/rechage_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RechageView extends GetView<RechageController> {
  const RechageView({super.key});

  // Shimmer widget for loading state
  Widget offerShimmer(double kHeight) {
    return Container(
      margin: EdgeInsets.all(kHeight * 0.012),
      padding: EdgeInsets.all(kHeight * 0.01),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(height: kHeight * 0.3, color: Colors.grey.shade700),
                const SizedBox(height: 4),
                Container(
                    height: kHeight * 0.02,
                    width: kHeight * 0.1,
                    color: Colors.grey.shade700),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) => Column(
                children: [
                  Container(
                      height: kHeight * 0.08, color: Colors.grey.shade700),
                  const SizedBox(height: 4),
                  Container(
                      height: kHeight * 0.015, color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RechageController rechageController = Get.put(RechageController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: kHeight * 0.15),
              child: SizedBox(
                height: kHeight * 0.8,
                child: FutureBuilder(
                  future: rechageController.showRechargeOffer(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Show shimmer placeholders while loading
                      return ListView.builder(
                        itemCount: 4,
                        itemBuilder: (context, index) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade100,
                          highlightColor: Colors.grey.shade500,
                          child: offerShimmer(kHeight),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return  Center(child: Text(("Error loading offers").appTr));
                    }
                    if (rechageController.rechargeOfferList.isEmpty) {
                      return  Center(child: Text(("No offers available").appTr));
                    }

                    return ListView.builder(
                      itemCount: rechageController.rechargeOfferList.length,
                      itemBuilder:
                          (BuildContext context, int rechargeOfferIndex) {
                        final rechargeOffer = rechageController
                            .rechargeOfferList[rechargeOfferIndex];
                        final assets = rechargeOffer['assets'] as List;

                        return Container(
                          margin: EdgeInsets.only(bottom: kHeight * 0.02),
                          child: Column(
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount:
                                    rechageController.rechargeOfferList.length,
                                itemBuilder: (BuildContext context,
                                    int rechargeOfferIndex) {
                                  final rechargeOffer = rechageController
                                      .rechargeOfferList[rechargeOfferIndex];
                                  final assets =
                                      rechargeOffer['assets'] as List;

                                  return Container(
                                    margin: EdgeInsets.all(kHeight * 0.012),
                                    padding: EdgeInsets.all(kHeight * 0.01),
                                    decoration: BoxDecoration(
                                      color: kAppColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: kAppColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Center(
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                '$kDomainUrl/${rechargeOffer['offer_image']}',
                                            height: kHeight * 0.06,
                                            width: 120,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const CircularProgressIndicator(),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error,
                                                        color: Colors.red,
                                                        size: 40),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (assets.isNotEmpty)
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      alignment:
                                                          Alignment.center,
                                                      height: kHeight * 0.3,
                                                      margin:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child:
                                                            CachedNetworkImage(
                                                          imageUrl:
                                                              '$kDomainUrl/${assets[0]['asset']}',
                                                          height:
                                                              kHeight * 0.12,
                                                          width: kHeight * 0.12,
                                                          fit: BoxFit.cover,
                                                          placeholder: (context,
                                                                  url) =>
                                                              const Center(
                                                                  child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2)),
                                                          errorWidget: (context,
                                                                  url, error) =>
                                                              const Icon(
                                                                  Icons.error,
                                                                  color: Colors
                                                                      .red),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      assets[0]['type'] ?? '',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: GoogleFonts.roboto(
                                                        fontSize:
                                                            kHeight * 0.019,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (assets.length > 1)
                                                Expanded(
                                                  flex: 2,
                                                  child: SizedBox(
                                                    height: kHeight * 0.37,
                                                    child: GridView.builder(
                                                      padding: EdgeInsets.only(
                                                          top: kHeight * 0.01),
                                                      shrinkWrap: true,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount:
                                                          assets.length - 1,
                                                      gridDelegate:
                                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: 2,
                                                        crossAxisSpacing: 2,
                                                        mainAxisSpacing: 2,
                                                        childAspectRatio: 0.8,
                                                      ),
                                                      itemBuilder:
                                                          (context, index) {
                                                        final rightAsset =
                                                            assets[index + 1];
                                                        return Column(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                      kHeight *
                                                                          0.01),
                                                              height: kHeight *
                                                                  0.08,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                                border: Border.all(
                                                                    color:
                                                                        kAppColor),
                                                              ),
                                                              child:
                                                                  CachedNetworkImage(
                                                                imageUrl:
                                                                    '$kDomainUrl/${rightAsset['asset']}',
                                                                height:
                                                                    kHeight *
                                                                        0.06,
                                                                width: kHeight *
                                                                    0.06,
                                                                fit: BoxFit
                                                                    .cover,
                                                                placeholder: (context,
                                                                        url) =>
                                                                    const Center(
                                                                        child: CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2)),
                                                                errorWidget: (context,
                                                                        url,
                                                                        error) =>
                                                                    const Icon(
                                                                        Icons
                                                                            .error,
                                                                        color: Colors
                                                                            .red),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              rightAsset[
                                                                      'type'] ??
                                                                  '',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: GoogleFonts
                                                                  .roboto(
                                                                color: Colors
                                                                    .white,
                                                                fontSize:
                                                                    kHeight *
                                                                        0.014,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              height: kHeight * 0.1,
            ),
          ],
        ),
      ),
    );
  }
}

class CastomRechargeCard extends StatelessWidget {
  final String text;
  const CastomRechargeCard({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: kHeight * 0.1,
          padding: EdgeInsets.symmetric(
              vertical: kHeight * 0.015, horizontal: kWeight * 0.03),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0xfff30909), width: 3)),
          child: Center(
            child: Image(
              image: AssetImage(''),
              height: kHeight * 0.04,
            ),
          ),
        ),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 15, // adjust as needed
            fontWeight: FontWeight.bold,
            color: Color(0xff070606),
          ),
        ),
      ],
    );
  }
}
