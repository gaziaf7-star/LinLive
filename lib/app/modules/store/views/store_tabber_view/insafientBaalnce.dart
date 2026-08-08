import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:meetlivepro/app/modules/accountInfornation/views/CoinTopup.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
void showInsufficientCoinsDialog({
  required dynamic userCoins,
  required dynamic assetPrice,
}) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 74,
              width: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.diamond_rounded,
                color: Color(0xFFFFB300),
                size: 42,
              ),
            ),

            const SizedBox(height: 18),

             Text(
              ("Not Enough Coins").appTr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F),
              ),
            ),

            const SizedBox(height: 10),

             Text(
              ("You do not have enough coins to purchase this premium asset.").appTr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF707070),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEDEDED),
                ),
              ),
              child: Column(
                children: [
                  _coinInfoRow(
                    title: ("Your Coins").appTr,
                    value: "$userCoins",
                  ),
                  const SizedBox(height: 10),
                  _coinInfoRow(
                    title: ("Asset Price").appTr,
                    value: "$assetPrice",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:  Text(
                        ("Cancel").appTr,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.back();

                      // Recharge page route এখানে আপনার project অনুযায়ী বসাবেন
                      // Example:
                      Get.to(() => CoinTopUp());
                      //
                      // Get.toNamed('/recharge');
                    },
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient:  LinearGradient(
                          colors: [
                            kAppColor2,kAppColor1
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child:  Text(
                        ("Recharge").appTr,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}

Widget _coinInfoRow({
  required String title,
  required String value,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF777777),
        ),
      ),
      Row(
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFB300),
            size: 20,
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Poppins",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    ],
  );
}