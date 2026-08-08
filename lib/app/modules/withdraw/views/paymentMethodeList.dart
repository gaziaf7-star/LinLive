import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/constants/image_helper.dart';

import '../../../../constants/layout_constant.dart';
import '../../accountInfornation/views/widget/CastomBtton.dart';
import '../controllers/withdraw_controller.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class PaymentMethodList extends StatefulWidget {
  const PaymentMethodList({Key? key}) : super(key: key);

  @override
  State<PaymentMethodList> createState() => _PaymentMethodListState();
}

class _PaymentMethodListState extends State<PaymentMethodList> {
  final WithdrawController withdrawController = Get.put(WithdrawController());

  String? _selectedId;

  final List<int> allowedAmounts = [
    200000,
    500000,
    1000000,
    2000000,
    4000000,
    6000000,
    8000000,
    10000000,
    15000000,
    20000000,
    35000000,
    50000000,
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    withdrawController.getWithdrawList();
  }

  void _openWithdrawBottomSheet(Map item) {
    withdrawController.receivedType.value = 'admin';
    withdrawController.selectedResellerId.value = null;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: Get.height * 0.90,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Get.width * 0.05,
            vertical: Get.height * 0.018,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F8FB),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.16),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),

                  SizedBox(height: Get.height * 0.018),

                  Row(
                    children: [
                      Container(
                        height: Get.height * 0.052,
                        width: Get.height * 0.052,
                        padding: EdgeInsets.all(Get.width * 0.025),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              kAppColor1,
                              kAppColor2,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kAppColor2.withOpacity(.30),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _buildLogo(item['method_name']),
                      ),

                      SizedBox(width: Get.width * 0.035),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ("Selected Method").appTr,
                              style: GoogleFonts.poppins(
                                fontSize: Get.height * 0.0125,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              item['method_name']?.toString() ?? ('Unknown').appTr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: Get.height * 0.020,
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: Get.height * 0.003),
                            Text(
                              ("Account: ${item['method_account'] ?? ''}").appTr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: Get.height * 0.013,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          height: Get.height * 0.040,
                          width: Get.height * 0.040,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(.06),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black87,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Get.height * 0.025),

                  TextFormField(
                    keyboardType: TextInputType.number,
                    controller: withdrawController.amount,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: Get.height * 0.020,
                      color: Colors.black,
                    ),
                    cursorColor: kAppColor1,
                    decoration: InputDecoration(
                      hintText: ('Enter amount').appTr,
                      prefixIcon: const Icon(
                        Icons.diamond_rounded,
                        color: kAppColor1,
                      ),
                      hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: Get.height * 0.016,
                        color: Colors.black38,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: Get.width * 0.04,
                        vertical: Get.height * 0.018,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: kAppColor2.withOpacity(.16),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: kAppColor2.withOpacity(.16),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: kAppColor2,
                          width: 1.4,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }

                      final amount = int.tryParse(value);
                      if (amount == null) {
                        return 'Enter a valid number';
                      }

                      if (!allowedAmounts.contains(amount)) {
                        return 'Invalid amount';
                      }

                      return null;
                    },
                  ),

                  SizedBox(height: Get.height * 0.022),

                  Obx(() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ("Received Type").appTr,
                          style: GoogleFonts.poppins(
                            fontSize: Get.height * 0.016,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),

                        SizedBox(height: Get.height * 0.012),

                        Row(
                          children: [
                            Expanded(
                              child: _receivedTypeCard(
                                title: ("Admin").appTr,
                                icon: Icons.admin_panel_settings_rounded,
                                selected:
                                withdrawController.receivedType.value ==
                                    'admin',
                                onTap: () {
                                  withdrawController.receivedType.value =
                                  'admin';
                                  withdrawController.selectedResellerId.value =
                                  null;
                                },
                              ),
                            ),

                            SizedBox(width: Get.width * 0.03),

                            Expanded(
                              child: _receivedTypeCard(
                                title: ("Reseller").appTr,
                                icon: Icons.storefront_rounded,
                                selected:
                                withdrawController.receivedType.value ==
                                    'reseller',
                                onTap: () async {
                                  withdrawController.receivedType.value =
                                  'reseller';

                                  if (withdrawController.resellerList.isEmpty) {
                                    await withdrawController.getResellerList();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        if (withdrawController.receivedType.value ==
                            'reseller') ...[
                          SizedBox(height: Get.height * 0.018),
                          _resellerListBox(),
                        ],
                      ],
                    );
                  }),

                  SizedBox(height: Get.height * 0.025),

                  Obx(() {
                    return CastomAppButton(
                      fastColor: kAppColor2,
                      secondColor: kAppColor1,
                      onPressed: withdrawController.isLoading.value
                          ? () {}
                          : () {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        withdrawController.withdrawSubmit(
                          methodId: int.tryParse(item['id'].toString()) ?? 0,
                          selectedReceivedType: withdrawController.receivedType.value,
                          resellerId: withdrawController.selectedResellerId.value,
                        );
                      },
                      child: withdrawController.isLoading.value
                          ? SizedBox(
                        height: Get.height * 0.022,
                        width: Get.height * 0.022,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        ("Sure").appTr,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: Get.height * 0.016,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),

                  SizedBox(height: Get.height * 0.025),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;

    return Obx(() {
      final list = withdrawController.withDrawList;

      if (list.isEmpty) {
        return Center(
          child: Text(
            ('Set withdraw method first').appTr,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: height * 0.016,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          vertical: height * 0.015,
          horizontal: width * 0.04,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          final bool selected = item['id'].toString() == _selectedId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedId = item['id'].toString();
              });

              _openWithdrawBottomSheet(item);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(bottom: height * 0.015),
              padding: EdgeInsets.symmetric(
                vertical: height * 0.018,
                horizontal: width * 0.04,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: selected
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kAppColor1,
                    kAppColor2,
                    kAppbarColor,
                  ],
                )
                    : const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFFFF4F7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? kAppColor2.withOpacity(.30)
                        : Colors.black.withOpacity(.06),
                    blurRadius: selected ? 20 : 8,
                    offset: Offset(0, selected ? 10 : 6),
                  ),
                ],
                border: Border.all(
                  color: selected
                      ? Colors.white.withOpacity(.30)
                      : kAppColor2.withOpacity(.14),
                  width: selected ? 1.3 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: width * 0.14,
                    height: width * 0.14,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(.20)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: selected
                              ? Colors.white.withOpacity(.22)
                              : Colors.black.withOpacity(.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(width * 0.025),
                    child: _buildLogo(item['method_name']),
                  ),

                  SizedBox(width: width * 0.04),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['method_name'] ?? ('Unknown').appTr,
                          style: GoogleFonts.poppins(
                            fontSize: height * 0.019,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: height * 0.006),
                        Text(
                          item['method_account'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: height * 0.015,
                            color: selected ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: height * 0.010),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.025,
                                vertical: height * 0.004,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withOpacity(.20)
                                    : kAppColor2.withOpacity(.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ("Instant").appTr,
                                style: GoogleFonts.poppins(
                                  fontSize: height * 0.0125,
                                  color:
                                  selected ? Colors.white : kAppColor2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                            SizedBox(width: width * 0.025),

                            Text(
                              ("No extra fee").appTr,
                              style: GoogleFonts.poppins(
                                fontSize: height * 0.0125,
                                color:
                                selected ? Colors.white70 : Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? Colors.white : Colors.grey,
                        size: height * 0.028,
                      ),
                      SizedBox(height: height * 0.008),
                      Icon(
                        Icons.chevron_right_rounded,
                        color:
                        selected ? Colors.white70 : Colors.grey.shade400,
                        size: height * 0.030,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _receivedTypeCard({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          vertical: Get.height * 0.014,
          horizontal: Get.width * 0.025,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
            colors: [
              kAppColor1,
              kAppColor2,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFFFF4F7),
            ],
          ),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(.32)
                : kAppColor2.withOpacity(.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? kAppColor2.withOpacity(.28)
                  : Colors.black.withOpacity(.04),
              blurRadius: selected ? 18 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : kAppColor2,
              size: Get.height * 0.023,
            ),
            SizedBox(width: Get.width * 0.015),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: selected ? Colors.white : Colors.black87,
                fontSize: Get.height * 0.0145,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resellerListBox() {
    return Obx(() {
      if (withdrawController.resellerLoading.value) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(Get.width * 0.06),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kAppColor2.withOpacity(.12)),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: kAppColor2),
          ),
        );
      }

      if (withdrawController.resellerList.isEmpty) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(Get.width * 0.045),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.red.withOpacity(.15)),
          ),
          child: Text(
            ("No reseller found").appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.red,
              fontSize: Get.height * 0.014,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      return Container(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.36,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: withdrawController.resellerList.length,
          itemBuilder: (context, index) {
            final reseller = withdrawController.resellerList[index];

            final int resellerId =
                int.tryParse(reseller['id'].toString()) ?? 0;

            final String name =
                reseller['name']?.toString() ?? 'Unknown Reseller';
            final String phone =
                reseller['phone']?.toString() ?? 'N/A';
            final String email =
                reseller['email']?.toString() ?? 'N/A';
            final String image =
                reseller['profile_image']?.toString() ?? '';
            final String online =
                reseller['is_online']?.toString() ?? 'false';

            return Obx(() {
              final bool selected =
                  withdrawController.selectedResellerId.value == resellerId;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  withdrawController.selectedResellerId.value = resellerId;
                  withdrawController.selectedResellerId.refresh();

                  if (mounted) {
                    setState(() {});
                  }

                  print('✅ RESELLER SELECTED');
                  print('✅ selected reseller id: $resellerId');
                  print('✅ selected reseller full data: $reseller');
                  print(
                    '✅ controller selected id: ${withdrawController.selectedResellerId.value}',
                  );
                },
                child: AnimatedContainer(
                  key: ValueKey(
                    'reseller_${resellerId}_${withdrawController.selectedResellerId.value}',
                  ),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(bottom: Get.height * 0.012),
                  padding: EdgeInsets.all(Get.width * 0.035),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: selected
                        ? const LinearGradient(
                      colors: [
                        Color(0xFF101A3D),
                        kAppColor1,
                        kAppColor2,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFFFF4F7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withOpacity(.55)
                          : kAppColor2.withOpacity(.15),
                      width: selected ? 1.7 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? kAppColor2.withOpacity(.45)
                            : Colors.black.withOpacity(.05),
                        blurRadius: selected ? 24 : 8,
                        spreadRadius: selected ? 1 : 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: Get.height * 0.062,
                            width: Get.height * 0.062,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: selected
                                  ? const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8A00),
                                  Color(0xFFFF2D75),
                                ],
                              )
                                  : LinearGradient(
                                colors: [
                                  kAppColor1.withOpacity(.30),
                                  kAppColor2.withOpacity(.30),
                                ],
                              ),
                              boxShadow: selected
                                  ? [
                                BoxShadow(
                                  color:
                                  const Color(0xFFFFD700).withOpacity(.45),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                                  : [],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                ImageHelper.getImageUrl(image),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: selected
                                        ? Colors.white.withOpacity(.18)
                                        : kAppColor2.withOpacity(.08),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: selected ? Colors.white : kAppColor2,
                                      size: Get.height * 0.032,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: Get.height * 0.016,
                              width: Get.height * 0.016,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: online == 'true'
                                    ? const Color(0xFF00C853)
                                    : Colors.grey,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(width: Get.width * 0.03),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: Get.height * 0.016,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            SizedBox(height: Get.height * 0.004),

                            Text(
                              ("Phone: $phone").appTr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: selected ? Colors.white70 : Colors.black54,
                                fontSize: Get.height * 0.0125,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            SizedBox(height: Get.height * 0.002),

                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: selected ? Colors.white60 : Colors.black38,
                                fontSize: Get.height * 0.0115,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            SizedBox(height: Get.height * 0.006),

                            Row(
                              children: [
                                _miniResellerBadge(
                                  title: ("ID: $resellerId").appTr,
                                  selected: selected,
                                ),
                                SizedBox(width: Get.width * 0.015),
                                _miniResellerBadge(
                                  title: online == 'true' ? ("Online").appTr: ("Offline").appTr,
                                  selected: selected,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: selected
                            ? Container(
                          key: const ValueKey('selected_icon'),
                          height: Get.height * 0.032,
                          width: Get.height * 0.032,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.22),
                            border: Border.all(
                              color: Colors.white.withOpacity(.65),
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: Get.height * 0.022,
                          ),
                        )
                            : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey('unselected_icon'),
                          color: Colors.grey,
                          size: Get.height * 0.029,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        ),
      );
    });
  }
  Widget _miniResellerBadge({
    required String title,
    required bool selected,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.02,
        vertical: Get.height * 0.003,
      ),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(.18)
            : kAppColor2.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: selected ? Colors.white : kAppColor2,
          fontSize: Get.height * 0.0105,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLogo(String? methodName) {
    final name = methodName?.toLowerCase() ?? '';

    String asset = 'assets/images/default_wallet.png';

    if (name == 'bkash') {
      asset = 'assets/audio_live/BKash-Icon2-Logo.wine.png';
    } else if (name == 'nagad') {
      asset = 'assets/audio_live/Nagad-Vertical-Logo.wine.png';
    } else if (name.contains('card')) {
      asset = 'assets/images/card.png';
    }

    return Image.asset(
      asset,
      height: kHeight * 0.07,
      width: kHeight * 0.07,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.account_balance_wallet_rounded,
          size: 28,
          color: kAppColor2,
        );
      },
    );
  }
}