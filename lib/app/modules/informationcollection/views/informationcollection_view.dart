import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/app/modules/informationcollection/views/permissionOwnerPage.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/CustomInfoTextField.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../../../widgets/setheight.dart';
import '../../../../widgets/small_text_widgets.dart';
import '../controllers/informationcollection_controller.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class InformationcollectionView extends GetView<InformationcollectionController> {
  const InformationcollectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final InformationcollectionController controller =
    Get.put(InformationcollectionController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: ('Creator information').appTr,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD1DB),
                  Color(0xFFFDE9F1),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                kWeight * 0.04,
                kHeight * 0.025,
                kWeight * 0.04,
                kHeight * 0.035,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Castontext(
                      fontSize: kHeight * 0.016,
                      fontWeight: FontWeight.w700,
                      text: ('Apply for Creator Center').appTr,
                    ),
                  ),

                  SizedBox(height: kHeight * 0.006),

                  Center(
                    child: Text(
                      ('NID card is not required. Upload a clear profile image. Permission Owner is optional.').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: kHeight * 0.0125,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),

                  SizedBox(height: kHeight * 0.022),

                  _ProfileImageCard(controller: controller),

                  SizedBox(height: kHeight * 0.016),

                  _OwnerSelectCard(controller: controller),

                  SizedBox(height: kHeight * 0.024),

                  CustomInfoTextField(
                    controller: controller.agencyName,
                    text: '* Creator name',
                  ),

                  CustomInfoTextField(
                    controller: controller.agencyId,
                    text: '* Creator ID',
                    readOnly: true,
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: TextFormField(
                      controller: controller.whatsappNumber,
                      cursorColor: Colors.black,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                      style: GoogleFonts.lato(
                        color: Colors.black,
                        fontSize: kHeight * 0.016,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintStyle: GoogleFonts.lato(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: kHeight * 0.012,
                          vertical: kHeight * 0.014,
                        ),
                        hintText: ('* WhatsApp Number').appTr,
                        fillColor: Colors.white,
                        filled: true,
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                  ),

                  CustomInfoTextField(
                    controller: controller.email,
                    text: 'Enter Email',
                  ),

                  CustomInfoTextField(
                    controller: controller.address,
                    text: '* Enter Address',
                  ),

                  SetHeight(heightSet: 0.025),

                  _SubmitButton(controller: controller),

                  SetHeight(heightSet: 0.018),

                  SmallTextStyle(
                    color: Colors.black,
                    text:
                    ('Your information will be reviewed manually. Permission Owner is optional, but the required fields and profile image must be correct.').appTr,
                    fontSize: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileImageCard extends StatelessWidget {
  const _ProfileImageCard({required this.controller});

  final InformationcollectionController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool hasImage = controller.profileImagePath.value.isNotEmpty;

      return InkWell(
        onTap: controller.pickProfileImage,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: EdgeInsets.all(kHeight * 0.018),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                kAppColor2,
                kAppColor1
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color:   kAppColor2
                    .withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: kHeight * 0.095,
                width: kHeight * 0.095,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.4,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage: hasImage
                      ? FileImage(File(controller.profileImagePath.value))
                      : null,
                  child: !hasImage
                      ? Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: kHeight * 0.04,
                  )
                      : null,
                ),
              ),

              SizedBox(width: kWeight * 0.035),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasImage
                          ? ('Profile Image Selected').appTr: ('Upload Profile Image').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: kHeight * 0.017,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: kHeight * 0.006),
                    Text(
                      hasImage
                          ? ('Tap to change image').appTr: ('NID card লাগবে না, শুধু clear profile photo দিন।').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: kHeight * 0.0125,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: kHeight * 0.045,
                width: kHeight * 0.045,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _OwnerSelectCard extends StatelessWidget {
  const _OwnerSelectCard({required this.controller});

  final InformationcollectionController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool hasOwner = controller.selectedOwnerId.value.isNotEmpty;

      return InkWell(
        onTap: () {
          Get.to(
                () => PermissionOwnerSelectView(),
            transition: Transition.rightToLeft,
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: EdgeInsets.all(kHeight * 0.018),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: kHeight * 0.07,
                width: kHeight * 0.07,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      kAppColor2,
                      kAppColor1
                    ],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white10,
                  backgroundImage:
                  hasOwner && controller.selectedOwnerImage.value.isNotEmpty
                      ? NetworkImage(controller.selectedOwnerImage.value)
                      : null,
                  child: !hasOwner || controller.selectedOwnerImage.value.isEmpty
                      ? const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  )
                      : null,
                ),
              ),

              SizedBox(width: kWeight * 0.035),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasOwner
                          ? controller.selectedOwnerName.value
                          : ('Select Permission Owner (Optional)').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: kHeight * 0.016,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: kHeight * 0.004),
                    Text(
                      hasOwner
                          ? ('${controller.selectedOwnerRole.value} • ID: ${controller.selectedOwnerId.value}').appTr: ('চাইলে Super Admin / BD Admin select করুন').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: kHeight * 0.0125,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                hasOwner
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: hasOwner ? Colors.green : Colors.black45,
                size: hasOwner ? 25 : 17,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.controller});

  final InformationcollectionController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool active =
          controller.isFormFilled.value && !controller.createLoading.value;

      return Center(
        child: SizedBox(
          width: kWeight * 0.76,
          height: kHeight * 0.06,
          child: ElevatedButton(
            onPressed: active ? controller.createAgency : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              disabledBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: active
                      ? [
                    kAppColor2,
                    kAppColor1
                  ]
                      : [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Container(
                alignment: Alignment.center,
                child: controller.createLoading.value
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  ('Submit').appTr,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: kHeight * 0.02,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}