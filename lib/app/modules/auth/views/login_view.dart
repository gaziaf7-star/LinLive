

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../registersteps/controllers/registersteps_controller.dart';
import 'forget_password.dart';
import 'welcome_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  Map<String, dynamic> _arguments() {
    final dynamic raw = Get.arguments;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final RegisterstepsController loginController =
    Get.isRegistered<RegisterstepsController>()
        ? Get.find<RegisterstepsController>()
        : Get.put(RegisterstepsController());

    final Map<String, dynamic> args = _arguments();
    final bool blockedByAdmin = args['account_blocked'] == true;
    final bool blockedDevice = args['device_blocked'] == true;
    final String blockedMessage =
        args['message']?.toString().trim() ?? '';
    final String blockReason =
        args['reason']?.toString().trim() ?? '';
    final String unblockAt =
        args['unblock_at']?.toString().trim() ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _handleBack(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 700;

                return Stack(
                  children: <Widget>[
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LoginBackgroundPainter(),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        22,
                        compact ? 14 : 24,
                        22,
                        28 + MediaQuery.of(context).viewInsets.bottom * .12,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 42,
                        ),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildTopBar(context),
                              SizedBox(height: compact ? 20 : 36),
                              _buildBrandMark(compact: compact),
                              SizedBox(height: compact ? 18 : 28),
                              if (blockedByAdmin || blockedDevice)
                                _BlockedAccountCard(
                                  title: blockedDevice
                                      ? ('Device blocked').appTr
                                      : ('Account blocked').appTr,
                                  message: blockedMessage.isEmpty
                                      ? blockedDevice
                                      ? 'This device has been blocked by the administrator.'
                                      : 'Your account has been blocked by the administrator.'
                                      : blockedMessage,
                                  reason: blockReason,
                                  unblockAt: unblockAt,
                                ),
                              if (blockedByAdmin || blockedDevice)
                                SizedBox(height: compact ? 16 : 20),
                              Text(
                                ('Welcome back').appTr,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xff171922),
                                  fontSize: compact ? 25 : 29,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ('Sign in with your phone number to continue')
                                    .appTr,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xff777b89),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: compact ? 22 : 30),
                              _LoginField(
                                controller: loginController.loginPhone,
                                label: ('Phone number').appTr,
                                hint: ('Enter phone number').appTr,
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const <String>[
                                  AutofillHints.telephoneNumber,
                                ],
                                error: loginController.loginPhoneError,
                                onChanged: loginController.onPhoneChanged,
                              ),
                              const SizedBox(height: 15),
                              Obx(
                                    () => _LoginField(
                                  controller:
                                  loginController.loginPassword,
                                  label: ('Password').appTr,
                                  hint: ('Enter password').appTr,
                                  icon: Icons.lock_outline_rounded,
                                  keyboardType:
                                  TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const <String>[
                                    AutofillHints.password,
                                  ],
                                  obscureText: loginController
                                      .loginObscurePassword.value,
                                  error:
                                  loginController.loginPasswordError,
                                  onChanged:
                                  loginController.onPasswordChanged,
                                  onSubmitted: (_) {
                                    _submit(loginController);
                                  },
                                  suffix: IconButton(
                                    tooltip: loginController
                                        .loginObscurePassword.value
                                        ? ('Show password').appTr
                                        : ('Hide password').appTr,
                                    onPressed:
                                    loginController.toggleLoginPassword,
                                    icon: Icon(
                                      loginController
                                          .loginObscurePassword.value
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: const Color(0xff8d91a0),
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Get.to(
                                          () => ForgetPasswordPage(),
                                      transition: Transition.rightToLeft,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                    const Color(0xff7b42e8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    ('Forgot password?').appTr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 17 : 24),
                              Obx(
                                    () => _LoginButton(
                                  loading:
                                  loginController.isLoading.value,
                                  enabled: loginController
                                      .loginPhoneText.value
                                      .trim()
                                      .isNotEmpty &&
                                      loginController
                                          .loginPasswordText.value
                                          .isNotEmpty &&
                                      loginController
                                          .loginPhoneError.value ==
                                          null &&
                                      loginController
                                          .loginPasswordError.value ==
                                          null,
                                  onPressed: () {
                                    _submit(loginController);
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 17,
                                    color: Color(0xff989ca8),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      ('Secure sign in protected by LIN LIVE')
                                          .appTr,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xff989ca8),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    Get.offAll(
          () => WelcomeView(),
      transition: Transition.leftToRightWithFade,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: <Widget>[
        Material(
          color: const Color(0xfff4f3f8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _handleBack(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19,
                color: Color(0xff252732),
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(
          ('Phone Login').appTr,
          style: GoogleFonts.poppins(
            color: const Color(0xff262832),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildBrandMark({required bool compact}) {
    return Column(
      children: <Widget>[
        Container(
          width: compact ? 76 : 88,
          height: compact ? 76 : 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xffff4d91),
                Color(0xff9b4df2),
                Color(0xff575cff),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xff9b4df2).withOpacity(.25),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'LIN LIVE',
          style: GoogleFonts.poppins(
            color: const Color(0xff181a22),
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  void _submit(RegisterstepsController controller) {
    if (controller.isLoading.value) return;
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext();
    controller.tryToSignIn();
  }
}

class _BlockedAccountCard extends StatelessWidget {
  const _BlockedAccountCard({
    required this.title,
    required this.message,
    required this.reason,
    required this.unblockAt,
  });

  final String title;
  final String message;
  final String reason;
  final String unblockAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xfffff3f3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffffd4d4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffffe1e1),
            ),
            child: const Icon(
              Icons.block_rounded,
              color: Color(0xffd83343),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff9b1c2a),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff6f323a),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (reason.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${('Reason').appTr}: $reason',
                    style: GoogleFonts.poppins(
                      color: const Color(0xff9b1c2a),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (unblockAt.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${('Unblock time').appTr}: $unblockAt',
                    style: GoogleFonts.poppins(
                      color: const Color(0xff9b1c2a),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.textInputAction,
    required this.autofillHints,
    required this.error,
    required this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final RxnString error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool hasError = error.value != null &&
          error.value!.trim().isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xff333640),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: GoogleFonts.poppins(
              color: const Color(0xff20222b),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xffa2a5af),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                icon,
                color: hasError
                    ? const Color(0xffd83343)
                    : const Color(0xff7b42e8),
                size: 21,
              ),
              suffixIcon: suffix,
              filled: true,
              fillColor: const Color(0xfff7f7fa),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 17,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xffffbfc4)
                      : const Color(0xffececf1),
                  width: 1.1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xffd83343)
                      : const Color(0xff7b42e8),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(
                  color: Color(0xffd83343),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: hasError
                ? Padding(
              key: ValueKey<String>(error.value!),
              padding: const EdgeInsets.only(left: 5, top: 6),
              child: Text(
                error.value!,
                style: GoogleFonts.poppins(
                  color: const Color(0xffd83343),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && !loading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: active
            ? const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xffff4d91),
            Color(0xffa348ed),
            Color(0xff585dff),
          ],
        )
            : const LinearGradient(
          colors: <Color>[
            Color(0xffd8d9df),
            Color(0xffcfd1d9),
          ],
        ),
        boxShadow: active
            ? <BoxShadow>[
          BoxShadow(
            color: const Color(0xff9d4be9).withOpacity(.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ]
            : const <BoxShadow>[],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.6,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ('Log in').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 9),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  const _LoginBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint topGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xffff4d91).withOpacity(.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .84, size.height * .08),
          radius: size.width * .55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .08),
      size.width * .55,
      topGlow,
    );

    final Paint bottomGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xff655cff).withOpacity(.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .06, size.height * .90),
          radius: size.width * .60,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * .06, size.height * .90),
      size.width * .60,
      bottomGlow,
    );

    final Paint dotPaint = Paint()
      ..color = const Color(0xff7b42e8).withOpacity(.055);

    for (int row = 0; row < 5; row++) {
      for (int column = 0; column < 5; column++) {
        canvas.drawCircle(
          Offset(
            20 + (column * 16),
            size.height * .22 + (row * 16),
          ),
          1.7,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) {
    return false;
  }
}
