import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../controllers/setting_controller.dart';

class LoginPassword extends StatefulWidget {
  const LoginPassword({super.key});

  @override
  State<LoginPassword> createState() => _LoginPasswordState();
}

class _LoginPasswordState extends State<LoginPassword> {
  late final SettingController controller;

  @override
  void initState() {
    super.initState();
    controller = SettingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool success = await controller.changePassword();

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              controller.firstVisibleError.appTr,
              style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      return;
    }

    final String message = controller.successMessage.value;
    controller.clearForm();

    Get.off(
          () => PasswordChangeSuccessPage(message: message),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 280),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required String errorText,
    required bool passwordHidden,
    required VoidCallback onVisibilityTap,
  }) {
    final bool hasError = errorText.trim().isNotEmpty;

    return InputDecoration(
      hintText: hintText.appTr,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(
        Icons.lock_outline,
        color: hasError ? Colors.red : null,
      ),
      suffixIcon: IconButton(
        onPressed: onVisibilityTap,
        icon: Icon(
          passwordHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Colors.grey.shade600,
        ),
      ),
      errorText: hasError ? errorText.appTr : null,
      errorMaxLines: 2,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: hasError
            ? const BorderSide(color: Colors.red, width: 1.2)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: hasError ? Colors.red : kAppColor1,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: ('Set Login Password ').appTr,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.04,
              vertical: kHeight * 0.018,
            ),
            child: Column(
              children: <Widget>[
                Obx(
                      () => TextField(
                    controller: controller.newPasswordController,
                    onChanged: controller.onNewPasswordChanged,
                    obscureText: controller.hideNewPassword.value,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      hintText: 'Enter new password',
                      errorText: controller.newPasswordError.value,
                      passwordHidden:
                      controller.hideNewPassword.value,
                      onVisibilityTap:
                      controller.toggleNewPasswordVisibility,
                    ),
                  ),
                ),
                Divider(
                  color: Colors.grey.withOpacity(0.3),
                ),
                Obx(
                      () => TextField(
                    controller:
                    controller.confirmPasswordController,
                    onChanged: controller.onConfirmPasswordChanged,
                    onSubmitted: (_) => _submitPassword(),
                    obscureText:
                    controller.hideConfirmPassword.value,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration(
                      hintText: 'Enter Confirm password',
                      errorText:
                      controller.confirmPasswordError.value,
                      passwordHidden:
                      controller.hideConfirmPassword.value,
                      onVisibilityTap:
                      controller.toggleConfirmPasswordVisibility,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(
                      () => SizedBox(
                    width: kWeight * 0.7,
                    height: kHeight * 0.055,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : _submitPassword,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor:
                        Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: controller.isLoading.value
                                ? <Color>[
                              Colors.grey.shade400,
                              Colors.grey.shade500,
                            ]
                                : <Color>[
                              kAppColor1,
                              kAppColor2,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius:
                          BorderRadius.circular(50),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: controller.isLoading.value
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                              AlwaysStoppedAnimation<
                                  Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : Text(
                            ('Submit').appTr,
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: kHeight * 0.018,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordChangeSuccessPage extends StatelessWidget {
  final String message;

  const PasswordChangeSuccessPage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Password Updated').appTr,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 62,
                    color: Color(0xFF16A05D),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  ('Password changed successfully').appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message.appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: kWeight * 0.7,
                  height: kHeight * 0.055,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            kAppColor1,
                            kAppColor2,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius:
                        BorderRadius.circular(50),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          ('Done').appTr,
                          style: GoogleFonts.lato(
                            color: Colors.white,
                            fontSize: kHeight * 0.018,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
