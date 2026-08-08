import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/auth_controller.dart';
import 'login_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({
    super.key,
    required this.email,
    required this.otp,
  });

  final String email;
  final String otp;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  late final AuthController _authController;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String get _password => _passwordController.text;
  String get _confirmPassword => _confirmPasswordController.text;

  bool get _hasMinimumLength => _password.length >= 8;
  bool get _passwordsMatch =>
      _confirmPassword.isNotEmpty && _password == _confirmPassword;

  void _showMessage({
    required bool success,
    required String message,
  }) {
    final String cleanMessage = message.trim().isEmpty
        ? (success ? ('Success').appTr : ('Something went wrong').appTr)
        : message.trim();

    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: cleanMessage,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor:
      success ? const Color(0xff15995d) : const Color(0xffd83343),
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Future<void> _resetPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext();

    bool valid = true;

    if (_password.isEmpty) {
      _passwordError = ('Please enter a new password').appTr;
      valid = false;
    } else if (_password.length < 8) {
      _passwordError = ('Password must contain at least 8 characters').appTr;
      valid = false;
    } else {
      _passwordError = null;
    }

    if (_confirmPassword.isEmpty) {
      _confirmPasswordError = ('Please confirm your new password').appTr;
      valid = false;
    } else if (_password != _confirmPassword) {
      _confirmPasswordError = ('Passwords do not match').appTr;
      valid = false;
    } else {
      _confirmPasswordError = null;
    }

    setState(() {});

    if (!valid) {
      final String message =
          _passwordError ?? _confirmPasswordError ?? ('Please fill all fields').appTr;
      _showMessage(success: false, message: message);

      if (_passwordError != null) {
        _passwordFocusNode.requestFocus();
      } else {
        _confirmPasswordFocusNode.requestFocus();
      }
      return;
    }

    final ForgotPasswordResult result =
    await _authController.resetForgotPassword(
      email: widget.email,
      otp: widget.otp,
      password: _password,
      passwordConfirmation: _confirmPassword,
    );

    if (!mounted) return;

    if (!result.success) {
      _showMessage(success: false, message: result.message);
      return;
    }

    _showMessage(success: true, message: result.message);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    Get.offAll(
          () => const LoginView(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ResetPasswordBackgroundPainter(),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  28 + media.viewInsets.bottom * .12,
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildTopBar(),
                      const SizedBox(height: 28),
                      _buildHero(),
                      const SizedBox(height: 25),
                      _buildProgress(),
                      const SizedBox(height: 28),
                      _PasswordField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        label: ('New password').appTr,
                        hint: ('Enter a secure new password').appTr,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.newPassword],
                        errorText: _passwordError,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          } else {
                            setState(() {});
                          }
                        },
                        onSubmitted: (_) =>
                            _confirmPasswordFocusNode.requestFocus(),
                        onToggleVisibility: () {
                          setState(() => _hidePassword = !_hidePassword);
                        },
                      ),
                      const SizedBox(height: 15),
                      _PasswordField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        label: ('Confirm password').appTr,
                        hint: ('Re-enter your new password').appTr,
                        obscureText: _hideConfirmPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.newPassword],
                        errorText: _confirmPasswordError,
                        onChanged: (_) {
                          if (_confirmPasswordError != null) {
                            setState(() => _confirmPasswordError = null);
                          } else {
                            setState(() {});
                          }
                        },
                        onSubmitted: (_) => _resetPassword(),
                        onToggleVisibility: () {
                          setState(
                                () => _hideConfirmPassword = !_hideConfirmPassword,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _PasswordRequirement(
                        text: ('At least 8 characters').appTr,
                        valid: _hasMinimumLength,
                      ),
                      const SizedBox(height: 8),
                      _PasswordRequirement(
                        text: ('Both passwords match').appTr,
                        valid: _passwordsMatch,
                      ),
                      const SizedBox(height: 27),
                      Obx(
                            () => _PrimaryResetButton(
                          loading:
                          _authController.forgotPasswordResetting.value,
                          onPressed: _resetPassword,
                        ),
                      ),
                      const SizedBox(height: 18),
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
                              ('Your password is securely protected').appTr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xff989ca8),
                                fontSize: 11.3,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        Material(
          color: const Color(0xfff4f3f8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Get.back(),
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
          ('Reset Password').appTr,
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

  Widget _buildHero() {
    return Column(
      children: <Widget>[
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xffff4d91),
                Color(0xffa348ed),
                Color(0xff585dff),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xff9b4df2).withOpacity(.24),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.password_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          ('Create a new password').appTr,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xff171922),
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          ('Choose a strong password that you have not used before.').appTr,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xff777b89),
            fontSize: 12.8,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Row(
      children: const <Widget>[
        _ResetProgressStep(number: '1', label: 'Email', active: true),
        _ResetProgressLine(active: true),
        _ResetProgressStep(number: '2', label: 'Verify', active: true),
        _ResetProgressLine(active: true),
        _ResetProgressStep(number: '3', label: 'Reset', active: true),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.obscureText,
    required this.textInputAction,
    required this.autofillHints,
    required this.onChanged,
    required this.onToggleVisibility,
    this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onToggleVisibility;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.trim().isNotEmpty;

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
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: false,
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
              Icons.lock_outline_rounded,
              color: hasError
                  ? const Color(0xffd83343)
                  : const Color(0xff7b42e8),
              size: 21,
            ),
            suffixIcon: IconButton(
              tooltip: obscureText
                  ? ('Show password').appTr
                  : ('Hide password').appTr,
              onPressed: onToggleVisibility,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xff8d91a0),
                size: 21,
              ),
            ),
            filled: true,
            fillColor: const Color(0xfff7f7fa),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
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
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: hasError
              ? Padding(
            key: ValueKey<String>(errorText!),
            padding: const EdgeInsets.only(left: 5, top: 6),
            child: Text(
              errorText!,
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
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({
    required this.text,
    required this.valid,
  });

  final String text;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: Row(
        children: <Widget>[
          Icon(
            valid ? Icons.check_circle_rounded : Icons.circle_outlined,
            color:
            valid ? const Color(0xff15995d) : const Color(0xffa4a7b1),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              color:
              valid ? const Color(0xff137b4e) : const Color(0xff777b89),
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryResetButton extends StatelessWidget {
  const _PrimaryResetButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xffff4d91),
            Color(0xffa348ed),
            Color(0xff585dff),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xff9d4be9).withOpacity(.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ('Reset Password').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 9),
                const Icon(
                  Icons.check_circle_rounded,
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

class _ResetProgressStep extends StatelessWidget {
  const _ResetProgressStep({
    required this.number,
    required this.label,
    required this.active,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xff7b42e8),
          ),
          child: Text(
            number,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.appTr,
          style: GoogleFonts.poppins(
            color: const Color(0xff5f2fc0),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ResetProgressLine extends StatelessWidget {
  const _ResetProgressLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xff7b42e8),
        ),
      ),
    );
  }
}

class _ResetPasswordBackgroundPainter extends CustomPainter {
  const _ResetPasswordBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint topGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xffff4d91).withOpacity(.09),
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
          const Color(0xff655cff).withOpacity(.07),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .05, size.height * .92),
          radius: size.width * .62,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * .05, size.height * .92),
      size.width * .62,
      bottomGlow,
    );
  }

  @override
  bool shouldRepaint(covariant _ResetPasswordBackgroundPainter oldDelegate) {
    return false;
  }
}
