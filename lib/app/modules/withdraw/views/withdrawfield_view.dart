import 'dart:developer';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:meetlivepro/widgets/after/castom%20appbar.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/setheight.dart';
import '../../accountInfornation/views/widget/CastomBtton.dart';
import '../../wallet/controllers/wallet_controller.dart';
import '../controllers/withdraw_controller.dart';
import '../withdraw_account-add.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WithdrawfieldView extends GetView {
  const WithdrawfieldView({super.key});

  @override
  Widget build(BuildContext context) {
    WalletController controller = Get.put(WalletController());
    WithdrawController withdrawController = Get.put(
      WithdrawController(),
    );
    return Scaffold(
        appBar: CustomAppBar(
          title: ('Withdraw').appTr,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Castontext(text: ('Receive Withdrawal Amount').appTr),
              ),
              SetHeight(heightSet: 0.01),
              Center(
                child: SizedBox(
                  width: kWeight * 0.9,
                  child: TextFormField(
                    controller: withdrawController.amount,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        color: Colors.black),
                    cursorColor: Colors.black87,
                    decoration: InputDecoration(
                      hintText: ('Enter amount').appTr,
                      prefixIcon: Icon(
                        Icons.monetization_on_outlined,
                        color: Color(0xff813aec),
                      ),
                      hintStyle: GoogleFonts.lato(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      fillColor: Colors.grey.withOpacity(0.3),
                      filled: true,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              SetHeight(heightSet: 0.03),
              Obx(() {
                return Center(
                  child: CastomAppButton(
                    fastColor: withdrawController.isFormFilled.value
                        ? const Color(0xff8A4CF7)
                        : CupertinoColors.inactiveGray,
                    secondColor: withdrawController.isFormFilled.value
                        ? const Color(0xffB460F0)
                        : Colors.grey,
                    onPressed: withdrawController.isFormFilled.value
                        ? () {
                            withdrawController.withdrawPost();
                          }
                        : null,
                    buttonText: '',
                    child: withdrawController.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        :  Text(
                            ("Sure").appTr,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                );
              }),
              SetHeight(heightSet: 0.02),
              Center(
                child: CastomAppButton(
                  onPressed: () {
                    print('object');
                    Get.bottomSheet(
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => Get.back(),
                                  child: const Icon(Icons.close, size: 24),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                             Center(
                              child: Text(
                                ("Add account").appTr,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Castomtextfeild(
                              text:
                                  'Uid : ${authController.userProfile.value.user!.id}',
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                alignment: Alignment.center,
                                width: Get.width * 0.9,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CustomDropdown(
                                  closedHeaderPadding:
                                      const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  hintText: ('Select National ID Type').appTr,
                                  items: controller.nationalIdentity,
                                  initialItem: controller.nationalIdentity[0],
                                  canCloseOutsideBounds: true,
                                  decoration: CustomDropdownDecoration(
                                    closedSuffixIcon: const Icon(
                                      Icons.arrow_drop_down_outlined,
                                      color: Colors.black87,
                                    ),
                                    headerStyle: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    closedFillColor: Colors.white,
                                    listItemStyle: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                    hintStyle: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                    closedBorderRadius:
                                        BorderRadius.circular(8),
                                    expandedFillColor: Colors.white,
                                  ),
                                  onChanged: (value) {
                                    log('Changing value to: $value');
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Castomtextfeild(
                              text: 'Enter account number',
                            ),
                            const SizedBox(height: 20),
                            CastomAppButton(
                              onPressed: () {
                                Get.to(WithdrawfieldView(),
                                    transition: Transition.rightToLeft);
                              },
                              buttonText: ('Submit').appTr,
                            ),
                            SizedBox(
                              height: Get.height * 0.06,
                            )
                          ],
                        ),
                      ),
                      isScrollControlled: true,
                    );
                  },
                  buttonText: ('Modify withdrawal account').appTr,
                ),
              ),
            ],
          ),
        ));
  }
}
