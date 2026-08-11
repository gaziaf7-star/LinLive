import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

import 'google_registration_complete_view.dart';

class GoogleProfileSetupView extends StatefulWidget {
  const GoogleProfileSetupView({super.key});

  @override
  State<GoogleProfileSetupView> createState() =>
      _GoogleProfileSetupViewState();
}

class _GoogleProfileSetupViewState extends State<GoogleProfileSetupView> {
  late final RegisterstepsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RegisterstepsController>();
  }

  Future<void> _pickBirthday() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final DateTime now = DateTime.now();
    DateTime initial = DateTime(now.year - 18, 1, 1);
    final DateTime? current =
    DateTime.tryParse(controller.googleProfileDateOfBirth.value);

    if (current != null) {
      initial = current;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAppColor,
              onPrimary: Colors.white,
              onSurface: Color(0xff303030),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kAppColor,
                textStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.selectionClick();
      controller.setGoogleDateOfBirth(picked);
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool saved = await controller.submitGoogleProfileOnboarding();
    if (!saved || !mounted) return;

    Get.offAll(
          () => const GoogleRegistrationCompleteView(),
      transition: Transition.rightToLeftWithFade,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.width < 360;
    final double horizontal = compact ? 20 : 26;
    final double contentWidth = size.width > 560 ? 500 : size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xffFCFCFD),
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      6,
                      horizontal,
                      compact ? 18 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight -
                            (compact ? 24 : 30),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _StepHeader(currentStep: 2, totalSteps: 3),

                          SizedBox(height: compact ? 24 : 30),

                          Text(
                            'Complete your profile',
                            style: GoogleFonts.poppins(
                              fontSize: compact ? 22 : 25,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xff25262A),
                              letterSpacing: -0.35,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'A few details help people recognize you better.',
                            style: GoogleFonts.poppins(
                              fontSize: compact ? 11.5 : 12.3,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xff8A8D96),
                            ),
                          ),

                          SizedBox(height: compact ? 20 : 24),

                          _ProfileCard(
                            controller: controller,
                            compact: compact,
                          ),

                          SizedBox(height: compact ? 14 : 16),

                          _FieldCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(text: 'Username'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller:
                                  controller.googleProfileNameController,
                                  textInputAction: TextInputAction.done,
                                  cursorColor: kAppColor,
                                  style: GoogleFonts.poppins(
                                    fontSize: compact ? 14.2 : 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff303136),
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Enter your name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),

                                SizedBox(height: compact ? 13 : 15),

                                const _FieldLabel(text: 'Birthday'),
                                const SizedBox(height: 6),
                                Obx(() {
                                  final String birthday = controller
                                      .googleProfileDateOfBirth.value;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _pickBirthday,
                                    child: Container(
                                      height: compact ? 48 : 51,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF7F7F9),
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xffECECF0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                            size: 19,
                                            color: kAppColor,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              birthday.isEmpty
                                                  ? 'Select birthday'
                                                  : birthday,
                                              style: GoogleFonts.poppins(
                                                fontSize:
                                                compact ? 13.5 : 14.2,
                                                fontWeight: FontWeight.w600,
                                                color: birthday.isEmpty
                                                    ? const Color(0xffA7A9B0)
                                                    : const Color(0xff303136),
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: Color(0xff9A9CA3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                SizedBox(height: compact ? 13 : 15),

                                const _FieldLabel(text: 'Gender'),
                                const SizedBox(height: 7),

                                Obx(() {
                                  final String selected =
                                      controller.googleProfileGender.value;

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _GenderChoice(
                                          title: 'Male',
                                          icon: Icons.male_rounded,
                                          selected: selected == 'Male',
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            controller
                                                .selectGoogleGender('Male');
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: _GenderChoice(
                                          title: 'Female',
                                          icon: Icons.female_rounded,
                                          selected: selected == 'Female',
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            controller
                                                .selectGoogleGender('Female');
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }),

                                Obx(() {
                                  if (controller.googleProfileGender.value
                                      .isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Text(
                                      'Please select your gender',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.8,
                                        fontWeight: FontWeight.w500,
                                        color: kPostIconColor,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          SizedBox(height: compact ? 24 : 30),

                          Obx(() {
                            final bool loading =
                                controller.googleProfileSaving.value;

                            return Center(
                              child: SizedBox(
                                width: compact ? 190 : 215,
                                height: compact ? 45 : 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: loading
                                        ? const LinearGradient(
                                      colors: [
                                        Color(0xffC9C7C4),
                                        Color(0xffD8D5D1),
                                      ],
                                    )
                                        : const LinearGradient(
                                      colors: [
                                        kAppColor,
                                        kPostIconColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: loading
                                        ? const []
                                        : [
                                      BoxShadow(
                                        color: kPostIconColor
                                            .withOpacity(.16),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: loading ? null : _submit,
                                      borderRadius: BorderRadius.circular(24),
                                      child: Center(
                                        child: loading
                                            ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                            : Text(
                                          'Submit',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                            compact ? 14 : 14.8,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xffA7A9B0),
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: kAppColor,
      ),
      filled: true,
      fillColor: const Color(0xffF7F7F9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffECECF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffECECF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kAppColor.withOpacity(.65),
          width: 1.25,
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Get.back(),
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xff2A2B2F),
              ),
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: List.generate(totalSteps, (index) {
            final bool active = index < currentStep;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 24 : 8,
              height: 5,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: active ? kAppColor : const Color(0xffE1E2E6),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.controller,
    required this.compact,
  });

  final RegisterstepsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 13 : 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffEFEFF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            controller: controller,
            compact: compact,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 12.2 : 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff35363A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap the photo to change it',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 10.3 : 11,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xff9698A0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffEFEFF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xff747780),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.controller,
    required this.compact,
  });

  final RegisterstepsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 60 : 66;

    return GestureDetector(
      onTap: controller.pickGoogleProfileImage,
      child: Obx(() {
        final String localPath =
            controller.googleProfileImagePath.value;
        final String networkUrl =
            controller.googleProfilePhotoUrl.value;
        final String name =
        controller.googleProfileNameController.text.trim();

        final String initial =
        name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();

        Widget avatar;

        if (localPath.isNotEmpty) {
          avatar = Image.file(
            File(localPath),
            fit: BoxFit.cover,
            width: size,
            height: size,
          );
        } else if (networkUrl.isNotEmpty) {
          final String url = networkUrl.startsWith('http://') ||
              networkUrl.startsWith('https://')
              ? networkUrl
              : ImageHelper.getImageUrl(networkUrl);

          avatar = CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: size,
            height: size,
            fadeInDuration: Duration.zero,
            placeholder: (context, url) =>
                _InitialAvatar(initial: initial),
            errorWidget: (context, url, error) =>
                _InitialAvatar(initial: initial),
          );
        } else {
          avatar = _InitialAvatar(initial: initial);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffF1F1F3),
                border: Border.all(
                  color: kAppColor.withOpacity(.18),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar,
            ),
            Positioned(
              right: -2,
              bottom: 0,
              child: Container(
                width: compact ? 23 : 25,
                height: compact ? 23 : 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kAppColor, kPostIconColor],
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: compact ? 12 : 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kAppColor, kPostIconColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 49,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? kAppColor.withOpacity(.075)
              : const Color(0xffF7F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? kAppColor.withOpacity(.55)
                : const Color(0xffECECF0),
            width: selected ? 1.15 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? kAppColor
                  : const Color(0xffA7A9B0),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? kAppColor
                      : const Color(0xff747780),
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: kPostIconColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
