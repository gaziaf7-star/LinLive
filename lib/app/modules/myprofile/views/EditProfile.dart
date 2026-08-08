import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/myprofile/views/widgets/changeCoverImage.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../controllers/myprofile_controller.dart';
import 'SignaturePage.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Editprofile extends StatefulWidget {
  const Editprofile({super.key});

  @override
  State<Editprofile> createState() => _EditprofileState();
}

class _EditprofileState extends State<Editprofile> {
  late final MyprofileController controller;

  @override
  void initState() {
    super.initState();

    controller = Get.put(MyprofileController());

    /// ✅ COUNTRY SEARCH SELECT FIX:
    /// আগে syncProfileFormFromAuth() build method-এর ভিতরে ছিল।
    /// Country select করার পর Obx rebuild হলে আবার old auth country দিয়ে overwrite হয়ে যেত।
    /// এখন শুধু একবার initState এ sync হবে, তাই search করে country select করলেও show হবে।
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.syncProfileFormFromAuth();
    });
  }

  /// ✅ COUNTRY FLAG RANGEERROR FIX:
  /// country_picker er Country.flagEmoji empty countryCode hole crash kore.
  /// Tai countryCode valid 2 letter hole only flag generate korbo, otherwise empty.
  String _safeCountryFlag(Country country) {
    final String code = country.countryCode.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return '';
    }

    return String.fromCharCodes(
      code.codeUnits.map((unit) => unit + 127397),
    );
  }

  String _safeCountryName(Country country) {
    final String name = country.name.trim();

    if (name.isEmpty || name.toLowerCase() == 'null') {
      return ('Select Country').appTr;
    }

    return name;
  }

  void _openCountryPicker(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();

    showCountryPicker(
      context: context,
      showPhoneCode: false,
      useSafeArea: true,
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.82,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        inputDecoration: InputDecoration(
          hintText: ('Search country').appTr,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: kAppColor,
          ),
          filled: true,
          fillColor: const Color(0xffF6F7FB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(.18),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(.18),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: kAppColor.withOpacity(.65),
              width: 1.3,
            ),
          ),
        ),
        searchTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(.78),
        ),
      ),
      onSelect: (Country country) {
        /// ✅ COUNTRY SEARCH SELECT FIX:
        /// List থেকে select করুক বা search result থেকে select করুক,
        /// selectedCountry force refresh হবে এবং UI সাথে সাথে update হবে।
        FocusManager.instance.primaryFocus?.unfocus();
        controller.selectedCountry.value = country;
        controller.selectedCountry.refresh();

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      appBar: CustomAppBar(
        title: ('Edit Profile').appTr,
      ),
      body: SafeArea(
        child: Obx(
              () => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.015,
            ),
            child: Column(
              children: [

                _ProfilePhotoPicker(controller: controller),

                // _premiumCard(
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //
                //       // _titleText('Avatar', isSmall),
                //       Obx(() {
                //         final userProfile = authController.userProfile.value;
                //         final user = userProfile.user;
                //
                //         final profileImage = user?.profileImage ?? '';
                //
                //         // Only asset_histories frame, entry_histories never use here
                //         final framePath =
                //             userProfile.assetHistories?.asset?.asset?.toString() ?? '';
                //
                //         final agencyId =
                //             int.tryParse(user?.agencyId?.toString() ?? '0') ?? 0;
                //
                //         final bool hasUserFrame =
                //             userProfile.assetHistories != null &&
                //                 framePath.isNotEmpty &&
                //                 userProfile.assetHistories?.asset?.type == 'Frame';
                //
                //         final bool hasAgencyFrame = !hasUserFrame && agencyId > 0;
                //
                //         final baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
                //         final frameUrl = '$baseUrl/$framePath';
                //
                //         print('Asset Histories => ${userProfile.assetHistories}');
                //         print('Entry Histories => ${userProfile.entryHistories}');
                //         print('Frame Path => $framePath');
                //         print('Frame Url => $frameUrl');
                //         print('Has User Frame => $hasUserFrame');
                //
                //         return Container(
                //           height: kHeight * 0.1,
                //           width: kHeight * 0.11,
                //           decoration: BoxDecoration(
                //             shape: BoxShape.circle,
                //             boxShadow: [
                //               BoxShadow(
                //                 color: Colors.black12,
                //                 blurRadius: 10,
                //                 spreadRadius: 2,
                //               )
                //             ],
                //           ),
                //           child: Stack(
                //             alignment: Alignment.center,
                //             children: [
                //               CircleAvatar(
                //                 radius: 42,
                //                 backgroundColor: Colors.white,
                //                 child: ClipRRect(
                //                   borderRadius: BorderRadius.circular(100),
                //                   child: CachedNetworkImage(
                //                     imageUrl: ImageHelper.getImageUrl(profileImage),
                //                     fit: BoxFit.cover,
                //                     height: 80,
                //                     width: 80,
                //                     placeholder: (c, u) =>
                //                     const CircularProgressIndicator(strokeWidth: 2),
                //                     errorWidget: (c, u, e) =>
                //                     const Icon(Icons.person, size: 50),
                //                   ),
                //                 ),
                //               ),
                //
                //               if (hasUserFrame)
                //                 SizedBox(
                //                   height: kHeight * 0.1,
                //                   width: kHeight * 0.11,
                //                   child: framePath.toLowerCase().endsWith('.svga')
                //                       ? SVGAEasyPlayer(
                //                     resUrl: frameUrl,
                //                     fit: BoxFit.cover,
                //                   )
                //                       : CachedNetworkImage(
                //                     imageUrl: frameUrl,
                //                     fit: BoxFit.cover,
                //                   ),
                //                 )
                //               else if (hasAgencyFrame)
                //                 SizedBox(
                //                   height: kHeight * 0.1,
                //                   width: kHeight * 0.11,
                //                   child: SVGAEasyPlayer(
                //                     assetsName: 'assets/svga/Frame/Agency frame.svga',
                //                     fit: BoxFit.cover,
                //                   ),
                //                 ),
                //             ],
                //           ),
                //         );
                //       }),
                //     ],
                //   ),
                // ),

                SizedBox(height: size.height * 0.015),

                Obx(
                      () => ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: CoverImagePicker(
                      localImagePath:
                      controller.picProfileImageCover.value.isEmpty
                          ? null
                          : controller.picProfileImageCover.value,
                      networkImageUrl:
                      authController.userProfile.value.user?.coverImages,
                      onTap: () {
                        controller.updateProfileCover();
                      },
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.018),

                _premiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(('Personal Information').appTr, isSmall),
                      const SizedBox(height: 14),

                      _inputField(
                        controller: controller.nameController,
                        label: ('Name').appTr,
                        icon: Icons.person_rounded,
                        keyboardType: TextInputType.name,
                      ),

                      const SizedBox(height: 12),

                      _inputField(
                        controller: controller.emailController,
                        label: ('Email').appTr,
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 12),

                      _inputField(
                        controller: controller.phoneController,
                        label: ('Phone').appTr,
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        ('Gender').appTr,
                        style: TextStyle(
                          fontSize: isSmall ? 12.5 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(.70),
                        ),
                      ),

                      const SizedBox(height: 9),

                      Row(
                        children: [
                          Expanded(
                            child: _genderChip(
                              title: ('Male').appTr,
                              icon: Icons.male_rounded,
                              selected:
                              controller.selectedGender.value == 'Male',
                              onTap: () {
                                controller.selectedGender.value = 'Male';
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _genderChip(
                              title: ('Female').appTr,
                              icon: Icons.female_rounded,
                              selected:
                              controller.selectedGender.value == 'Female',
                              onTap: () {
                                controller.selectedGender.value = 'Female';
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Obx(() {
                        final selected = controller.selectedCountry.value;
                        final String countryName = _safeCountryName(selected);
                        final String countryFlag = _safeCountryFlag(selected);

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openCountryPicker(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffF6F7FB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.grey.withOpacity(.16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  color: kAppColor,
                                  size: 21,
                                ),
                                const SizedBox(width: 12),
                                if (countryFlag.isNotEmpty) ...[
                                  Text(
                                    countryFlag,
                                    style: TextStyle(
                                      fontSize: isSmall ? 17 : 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    countryName.isEmpty
                                        ? ('Select Country').appTr: countryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSmall ? 13 : 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withOpacity(.70),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAppColor,
                            disabledBackgroundColor:
                            kAppColor.withOpacity(.55),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: controller.isProfileSaving.value
                              ? null
                              : () {
                            final id = authController
                                .userProfile.value.user?.id
                                ?.toInt();

                            if (id == null) {
                              return;
                            }

                            controller.profileUpdate(id: id);
                          },
                          child: controller.isProfileSaving.value
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                              :  Text(
                            ('Save Changes').appTr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      _softDivider(),

                      _profileTile(
                        title: ('Signature').appTr,
                        value: '',
                        isSmall: isSmall,
                        onTap: () {
                          Get.to(
                            Signaturepage(),
                            transition: Transition.rightToLeft,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _premiumCard({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _profileTile({
    required String title,
    required String value,
    required bool isSmall,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _titleText(title, isSmall),
            ),
            Expanded(
              flex: 4,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 12 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(.58),
                ),
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: isSmall ? 12 : 14,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _titleText(String text, bool isSmall) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: isSmall ? 13 : 14.5,
        fontWeight: FontWeight.w700,
        color: Colors.black.withOpacity(.78),
      ),
    );
  }

  static Widget _sectionTitle(String text, bool isSmall) {
    return Row(
      children: [
        Container(
          height: 28,
          width: 4,
          decoration: BoxDecoration(
            color: kAppColor,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w800,
            color: Colors.black.withOpacity(.82),
          ),
        ),
      ],
    );
  }

  static Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black.withOpacity(.78),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: kAppColor,
          size: 21,
        ),
        filled: true,
        fillColor: const Color(0xffF6F7FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.grey.withOpacity(.14),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.grey.withOpacity(.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: kAppColor.withOpacity(.65),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  static Widget _genderChip({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? kAppColor.withOpacity(.12)
              : const Color(0xffF6F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? kAppColor : Colors.grey.withOpacity(.16),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? kAppColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? kAppColor : Colors.black.withOpacity(.58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _softDivider() {
    return Divider(
      height: 1,
      thickness: .7,
      color: Colors.grey.withOpacity(.16),
    );
  }
}

class CastomTextLevel extends StatelessWidget {
  final String text;
  final String seText;

  const CastomTextLevel({
    super.key,
    required this.text,
    required this.seText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Castontext(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          text: text,
        ),
        Row(
          children: [
            Castontext(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              text: seText,
            ),
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 17,
                color: Colors.grey,
              ),
            )
          ],
        )
      ],
    );
  }
}

class _ProfilePhotoPicker extends StatelessWidget {
  final MyprofileController controller;

  const _ProfilePhotoPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final profileImage = authController.userProfile.value.user?.profileImage;

      return Row(
        children: [
          GestureDetector(
            onTap: () {
              controller.updateProfile();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: kHeight * 0.080,
                  width: kHeight * 0.080,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(
                      color: const Color(0xff10c7dc),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: controller.picProfileImage.value.isNotEmpty
                        ? Image.file(
                      File(controller.picProfileImage.value),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                        : CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(profileImage ?? ''),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: kHeight * 0.038,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: kHeight * 0.038,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    height: kHeight * 0.027,
                    width: kHeight * 0.027,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xff10c7dc),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: kHeight * 0.014,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: kHeight * 0.012),
          Expanded(
            child: GestureDetector(
              onTap: () {
                controller.updateProfile();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('Profile Photo').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: kHeight * 0.0145,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: kHeight * 0.003),
                  Text(
                    ('Tap here to change your profile image').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: kHeight * 0.0118,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
