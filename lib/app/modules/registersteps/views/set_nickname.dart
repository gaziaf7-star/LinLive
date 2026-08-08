import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../controllers/registersteps_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class SetNickname extends GetView<RegisterstepsController> {
  const SetNickname({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: ('Create Profile').appTr,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xfff7f4ff),
              Color(0xffffffff),
              Color(0xffeefbff),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: Get.width * 0.045,
              vertical: 18,
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Text(
                  ("Complete Your Identity").appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff1f1235),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  ("Add your profile details to continue").appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff7c748c),
                  ),
                ),

                const SizedBox(height: 24),

                _profileImagePicker(),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xffeee8ff),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff6c35ff).withOpacity(0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(("Personal Information").appTr),

                      const SizedBox(height: 14),

                      _countryPicker(context),

                      const SizedBox(height: 12),

                      _customTextField(
                        controller: controller.nickNameController,
                        hint: "Enter Nickname",
                        icon: Icons.person_rounded,
                        keyboardType: TextInputType.name,
                      ),

                      const SizedBox(height: 12),

                      _genderSelector(),

                      const SizedBox(height: 12),

                      _dateOfBirthPicker(context),

                      const SizedBox(height: 12),

                      _customTextField(
                        controller: controller.phoneNumberController,
                        hint: "Enter Phone Number",
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 12),

                      _customTextField(
                        controller: controller.emailController,
                        hint: "Enter Email",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 12),

                      Obx(
                            () => _customTextField(
                          controller: controller.passwordController,
                          hint: "Enter Password",
                          icon: Icons.lock_rounded,
                          obscureText: controller.obscurePassword.value,
                          suffixIcon: IconButton(
                            onPressed: controller.togglePassword,
                            icon: Icon(
                              controller.obscurePassword.value
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: const Color(0xff8c829d),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _inviteCodeField(),

                      const SizedBox(height: 22),

                      _submitButton(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: controller.singleFilePicker,
        child: Obx(
              () => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xff7a3cff),
                  Color(0xff20c7d9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff7a3cff).withOpacity(0.25),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 112,
                  width: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: controller.profile_image.value.isEmpty
                        ? Image.asset(
                      appLogo,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
                      File(controller.profile_image.value),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff1c1230),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 24,
          width: 5,
          decoration: BoxDecoration(
            color: kAppColor2,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kAppColor2,
          ),
        ),
      ],
    );
  }

  Widget _countryPicker(BuildContext context) {
    return Obx(
          () => GestureDetector(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: true,
            countryListTheme: CountryListThemeData(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              backgroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(
                color: kAppColor2,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              inputDecoration: InputDecoration(
                hintText: ('Search your country').appTr,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xff8c829d),
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xfff7f4ff),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            onSelect: (Country country) {
              controller.selected_language.value = country.name;
            },
          );
        },
        child: _selectBox(
          icon: Icons.public_rounded,
          title: controller.selected_language.value.isEmpty
              ? ("Select Country").appTr
              : controller.selected_language.value,
          isPlaceholder: controller.selected_language.value.isEmpty,
        ),
      ),
    );
  }

  Widget _genderSelector() {
    return Obx(
          () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ("Gender").appTr,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xff6d627d),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _genderCard(
                  title: ("Male").appTr,
                  icon: Icons.male_rounded,
                  value: "male",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _genderCard(
                  title: ("Female").appTr,
                  icon: Icons.female_rounded,
                  value: "female",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _genderCard(
                  title: ("Other").appTr,
                  icon: Icons.transgender_rounded,
                  value: "other",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderCard({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final bool selected = controller.selectedGender.value == value;

    return GestureDetector(
      onTap: () => controller.selectGender(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 54,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
            colors: [
              kAppColor2,
              kAppColor1
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: selected ? null : const Color(0xfff8f6ff),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xffeee8ff),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xff7a3cff).withOpacity(0.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white :kAppColor2,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xff31243f),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateOfBirthPicker(BuildContext context) {
    return Obx(
          () => GestureDetector(
        onTap: () async {
          FocusScope.of(context).unfocus();

          final DateTime now = DateTime.now();

          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 18, now.month, now.day),
            firstDate: DateTime(1950),
            lastDate: DateTime(now.year - 10, now.month, now.day),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: kAppColor2,
                    onPrimary: Colors.white,
                    onSurface: Color(0xff1f1235),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor:kAppColor2,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            controller.setDateOfBirth(picked);
          }
        },
        child: _selectBox(
          icon: Icons.calendar_month_rounded,
          title: controller.dataOfBirth.value.isEmpty
              ? ("Select Date of Birth").appTr
              : controller.dataOfBirth.value,
          isPlaceholder: controller.dataOfBirth.value.isEmpty,
        ),
      ),
    );
  }

  Widget _selectBox({
    required IconData icon,
    required String title,
    required bool isPlaceholder,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xfff8f6ff),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffeee8ff),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: kAppColor2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPlaceholder
                    ? const Color(0xff8c829d)
                    : const Color(0xff1f1235),
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xff8c829d),
          ),
        ],
      ),
    );
  }

  Widget _inviteCodeField() {
    return Obx(() {
      final state = controller.inviteCodeState.value;
      final error = controller.inviteCodeError.value;
      final message = controller.inviteCodeMessage.value;

      Color statusColor = const Color(0xff7c748c);
      if (state == InviteCodeValidationState.valid) {
        statusColor = Colors.green.shade700;
      } else if (state == InviteCodeValidationState.invalid) {
        statusColor = Colors.red.shade700;
      }

      Widget? suffix;
      if (state == InviteCodeValidationState.checking) {
        suffix = const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2.1,
              color: kAppColor2,
            ),
          ),
        );
      } else if (state == InviteCodeValidationState.valid) {
        suffix = const Icon(Icons.verified_rounded, color: Colors.green);
      } else if (state == InviteCodeValidationState.invalid) {
        suffix = const Icon(Icons.error_rounded, color: Colors.red);
      } else if (controller.inviteCodeController.text.trim().isNotEmpty) {
        suffix = IconButton(
          tooltip: ('Check code').appTr,
          onPressed: () => controller.validateInviteCode(),
          icon: const Icon(Icons.arrow_circle_right_rounded, color: kAppColor2),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller.inviteCodeController,
            onChanged: controller.onInviteCodeChanged,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: kAppColor2,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xff1f1235),
            ),
            decoration: InputDecoration(
              labelText: ('Invite Code (Optional)').appTr,
              hintText: ('Enter friend invite code').appTr,
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6d627d),
              ),
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xff8c829d),
              ),
              prefixIcon: const Icon(
                Icons.card_giftcard_rounded,
                size: 21,
                color: kAppColor2,
              ),
              suffixIcon: suffix,
              errorText: error,
              errorMaxLines: 2,
              filled: true,
              fillColor: const Color(0xfff8f6ff),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: state == InviteCodeValidationState.valid
                      ? Colors.green.shade300
                      : state == InviteCodeValidationState.invalid
                      ? Colors.red.shade300
                      : const Color(0xffeee8ff),
                  width: 1.1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: state == InviteCodeValidationState.valid
                      ? Colors.green
                      : state == InviteCodeValidationState.invalid
                      ? Colors.red
                      : kAppColor2,
                  width: 1.35,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.red, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.red, width: 1.35),
              ),
            ),
          ),
          if (message.isNotEmpty && error == null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    state == InviteCodeValidationState.valid
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      cursorColor: kAppColor2,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xff1f1235),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xff8c829d),
        ),
        prefixIcon: Icon(
          icon,
          size: 21,
          color: kAppColor2,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xfff8f6ff),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xffeee8ff),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: kAppColor2,
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return Obx(
          () => GestureDetector(
        onTap: controller.isLoading.value ? null : controller.tryToSignUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: controller.isLoading.value
                ? const LinearGradient(
              colors: [
                Color(0xffb8b1c7),
                Color(0xffb8b1c7),
              ],
            )
                : const LinearGradient(
              colors: [
                kAppColor2,
                kAppColor1
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff7a3cff).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: controller.isLoading.value
                ? const SizedBox(
              height: 23,
              width: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ("Sign Up").appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}