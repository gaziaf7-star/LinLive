import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/withdraw/views/paymentMethodeList.dart';

import '../../../constants/constants.dart';
import '../../../constants/layout_constant.dart';
import '../../../widgets/after/castom appbar.dart';
import '../accountInfornation/views/widget/CastomBtton.dart';
import '../wallet/controllers/wallet_controller.dart';
import 'controllers/withdraw_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WithdrawAccount extends StatefulWidget {
  WithdrawAccount({super.key});

  @override
  State<WithdrawAccount> createState() => _WithdrawAccountState();
}

class _WithdrawAccountState extends State<WithdrawAccount> {
  String? selectedPayment;
  final TextEditingController paymentController = TextEditingController();

  late WithdrawController withdrawController;


  @override
  void initState() {
    super.initState();

    withdrawController = Get.put(WithdrawController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      withdrawController.getWithdrawMethodeList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Account Details').appTr,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: kHeight * 0.04),

            Center(
              child: CastomAppButton(
                onPressed: () {
                  Get.bottomSheet(
                    SafeArea(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Get.width * 0.05,
                          vertical: Get.height * 0.02,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                              SizedBox(height: Get.height * 0.015),
                              Text(
                                ("Add account").appTr,
                                style: TextStyle(
                                  fontSize: Get.height * 0.025,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: Get.height * 0.025),
                              Castomtextfeild(
                                text:
                                'Uid : ${authController.userProfile.value.user?.userId ?? ""}',
                              ),
                              SizedBox(height: Get.height * 0.015),

                              Container(
                                alignment: Alignment.center,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Obx(() {
                                  final methodList =
                                      withdrawController.withdrawMethodeList;

                                  if (methodList.isEmpty) {
                                    return CustomDropdown<String>(
                                      closedHeaderPadding:
                                      EdgeInsets.symmetric(
                                        vertical: Get.height * 0.015,
                                        horizontal: Get.width * 0.04,
                                      ),
                                      hintText: ('Loading methods...').appTr,
                                      items: const [],
                                      canCloseOutsideBounds: true,
                                      decoration: CustomDropdownDecoration(
                                        closedSuffixIcon: const Icon(
                                          Icons.arrow_drop_down_outlined,
                                          color: Colors.black87,
                                        ),
                                        headerStyle: GoogleFonts.lato(
                                          fontSize: Get.height * 0.018,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                        closedFillColor: Colors.white,
                                        listItemStyle: GoogleFonts.lato(
                                          fontSize: Get.height * 0.018,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                        hintStyle: GoogleFonts.lato(
                                          fontSize: Get.height * 0.018,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                        closedBorderRadius:
                                        BorderRadius.circular(8),
                                        expandedFillColor: Colors.white,
                                      ),
                                      onChanged: (value) {},
                                    );
                                  }

                                  final List<String> methodNames = methodList
                                      .asMap()
                                      .entries
                                      .map<String>((entry) {
                                    final item = entry.value;
                                    final name =
                                        item['name']?.toString() ?? '';
                                    final id = item['id']?.toString() ?? '';

                                    // Same name duplicate thakle id shoho show korbe
                                    return '$name';
                                  }).toList();

                                  return CustomDropdown<String>(
                                    closedHeaderPadding:
                                    EdgeInsets.symmetric(
                                      vertical: Get.height * 0.015,
                                      horizontal: Get.width * 0.04,
                                    ),
                                    hintText: ('Select Withdraw Method').appTr,
                                    items: methodNames,
                                    initialItem: null,
                                    canCloseOutsideBounds: true,
                                    decoration: CustomDropdownDecoration(
                                      closedSuffixIcon: const Icon(
                                        Icons.arrow_drop_down_outlined,
                                        color: Colors.black87,
                                      ),
                                      headerStyle: GoogleFonts.lato(
                                        fontSize: Get.height * 0.018,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                      closedFillColor: Colors.white,
                                      listItemStyle: GoogleFonts.lato(
                                        fontSize: Get.height * 0.018,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                      hintStyle: GoogleFonts.lato(
                                        fontSize: Get.height * 0.018,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                      closedBorderRadius:
                                      BorderRadius.circular(8),
                                      expandedFillColor: Colors.white,
                                    ),
                                    onChanged: (value) {
                                      if (value == null) return;

                                      final selectedIndex =
                                      methodNames.indexOf(value);

                                      if (selectedIndex < 0) return;

                                      final selectedMethod =
                                      methodList[selectedIndex];

                                      withdrawController.selectMethode.value =
                                          selectedMethod['name']?.toString() ??
                                              '';

                                      withdrawController
                                          .selectedWithdrawMethodId.value =
                                          int.tryParse(
                                            selectedMethod['id']
                                                .toString(),
                                          ) ??
                                              0;

                                      print(
                                          "Selected method name: ${withdrawController.selectMethode.value}");
                                      print(
                                          "Selected method id: ${withdrawController.selectedWithdrawMethodId.value}");
                                      print(
                                          "Selected full method: $selectedMethod");
                                    },
                                  );
                                }),
                              ),

                              SizedBox(height: Get.height * 0.015),
                              Castomtextfeild(
                                controller: withdrawController.number,
                                text: 'Enter account number',
                              ),
                              SizedBox(height: Get.height * 0.025),
                              Obx(() {
                                return CastomAppButton(
                                  onPressed: () {
                                    if (withdrawController.isLoading.value) {
                                      return;
                                    }

                                    withdrawController.withdrawPost();
                                  },
                                  buttonText:
                                  withdrawController.isLoading.value
                                      ? 'Please wait...'
                                      : ('Submit').appTr,
                                );
                              }),
                              SizedBox(height: Get.height * 0.06),
                            ],
                          ),
                        ),
                      ),
                    ),
                    isScrollControlled: true,
                  );
                },
                buttonText: ('Add account').appTr,
              ),
            ),

            SizedBox(
              height: kHeight * 0.8,
              child: PaymentMethodList(),
            ),
          ],
        ),
      ),
    );
  }
}

class Castomtextfeild extends StatelessWidget {
  final String text;
  final TextEditingController? controller;

  const Castomtextfeild({
    super.key,
    required this.text,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          labelText: text,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xff8A4CF7),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}