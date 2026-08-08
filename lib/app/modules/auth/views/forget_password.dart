import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import '../controllers/auth_controller.dart';
import 'resent_password_page.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  late final AuthController _authController;
  late final Worker _profileEmailWorker;

  bool _otpSent = false;
  bool _emailEditedByUser = false;
  String? _emailError;
  String? _otpError;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController());

    _prefillAccountEmail();
    _profileEmailWorker = ever(
      _authController.userProfile,
          (_) => _prefillAccountEmail(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillAccountEmail();
    });
  }

  @override
  void dispose() {
    _profileEmailWorker.dispose();
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();
  String get _otp => _otpController.text.trim();

  void _prefillAccountEmail() {
    if (_emailEditedByUser) return;

    final String accountEmail = _authController.currentAccountEmail.trim();
    if (accountEmail.isEmpty || accountEmail.toLowerCase() == 'null') return;
    if (_emailController.text.trim().toLowerCase() ==
        accountEmail.toLowerCase()) {
      return;
    }

    _emailController.value = TextEditingValue(
      text: accountEmail,
      selection: TextSelection.collapsed(offset: accountEmail.length),
    );

    if (mounted && _emailError != null) {
      setState(() => _emailError = null);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

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

  Future<void> _sendOtp({bool resend = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final email = _email;
    if (email.isEmpty) {
      final String message = ('Please enter your email address').appTr;
      setState(() => _emailError = message);
      _showMessage(success: false, message: message);
      _emailFocusNode.requestFocus();
      return;
    }

    if (!_isValidEmail(email)) {
      final String message = ('Please enter a valid email address').appTr;
      setState(() => _emailError = message);
      _showMessage(success: false, message: message);
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() => _emailError = null);

    final ForgotPasswordResult result =
    await _authController.sendForgotPasswordOtp(email: email);

    if (!mounted) return;

    if (!result.success) {
      _showMessage(success: false, message: result.message);
      return;
    }

    setState(() {
      _otpSent = true;
      _otpError = null;
      if (!resend) _otpController.clear();
    });
    _startResendTimer();

    _showMessage(success: true, message: result.message);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });
  }

  Future<void> _verifyOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_otp.length != 6) {
      final String message =
          ('Please enter the complete 6-digit code').appTr;
      setState(() => _otpError = message);
      _showMessage(success: false, message: message);
      _otpFocusNode.requestFocus();
      return;
    }

    setState(() => _otpError = null);

    final ForgotPasswordResult result =
    await _authController.verifyForgotPasswordOtp(
      email: _email,
      otp: _otp,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _otpError = result.message);
      _showMessage(success: false, message: result.message);
      return;
    }

    _showMessage(success: true, message: result.message);

    Get.to(
          () => NewPasswordPage(email: _email, otp: _otp),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 260),
    );
  }

  void _changeEmail() {
    _emailEditedByUser = true;
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _otpError = null;
      _resendSeconds = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });
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
                    painter: _ForgotPasswordBackgroundPainter(),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _otpSent
                            ? _buildOtpStep(key: const ValueKey('otp_step'))
                            : _buildEmailStep(key: const ValueKey('email_step')),
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
          ('Forgot Password').appTr,
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
            Icons.lock_reset_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _otpSent
              ? ('Verify your email').appTr
              : ('Reset your password').appTr,
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
          _otpSent
              ? '${('We sent a 6-digit verification code to').appTr}\n$_email'
              : ('Enter your account email and we will send you a secure verification code.')
              .appTr,
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
      children: <Widget>[
        _ProgressStep(number: '1', label: ('Email').appTr, active: true),
        _ProgressLine(active: _otpSent),
        _ProgressStep(number: '2', label: ('Verify').appTr, active: _otpSent),
        const _ProgressLine(active: false),
        _ProgressStep(number: '3', label: ('Reset').appTr, active: false),
      ],
    );
  }

  Widget _buildEmailStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AuthField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          label: ('Email address').appTr,
          hint: ('Enter your registered email').appTr,
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.email],
          errorText: _emailError,
          onChanged: (_) {
            _emailEditedByUser = true;
            if (_emailError != null) setState(() => _emailError = null);
          },
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 24),
        Obx(
              () => _PrimaryActionButton(
            text: ('Send verification code').appTr,
            icon: Icons.send_rounded,
            loading: _authController.forgotPasswordSendingOtp.value,
            onPressed: () => _sendOtp(),
          ),
        ),
        const SizedBox(height: 17),
        _SecurityNote(
          text: ('For your security, the code will expire after a short time.')
              .appTr,
        ),
      ],
    );
  }

  Widget _buildOtpStep({required Key key}) {
    final PinTheme defaultTheme = PinTheme(
      width: 49,
      height: 57,
      textStyle: GoogleFonts.poppins(
        color: const Color(0xff20222b),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfff7f7fa),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffe7e7ee), width: 1.2),
      ),
    );

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Pinput(
          length: 6,
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          defaultPinTheme: defaultTheme,
          focusedPinTheme: defaultTheme.copyWith(
            decoration: defaultTheme.decoration!.copyWith(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xff7b42e8),
                width: 1.7,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xff7b42e8).withOpacity(.12),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          submittedPinTheme: defaultTheme.copyWith(
            decoration: defaultTheme.decoration!.copyWith(
              color: const Color(0xfff2edff),
              border: Border.all(color: const Color(0xffbca3f5)),
            ),
          ),
          errorPinTheme: defaultTheme.copyWith(
            decoration: defaultTheme.decoration!.copyWith(
              color: const Color(0xfffff5f5),
              border: Border.all(color: const Color(0xffd83343)),
            ),
          ),
          onChanged: (_) {
            if (_otpError != null) setState(() => _otpError = null);
          },
          onCompleted: (_) => _verifyOtp(),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _otpError == null
              ? const SizedBox(height: 12)
              : Padding(
            key: ValueKey<String>(_otpError!),
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _otpError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xffd83343),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              ('Did not receive the code?').appTr,
              style: GoogleFonts.poppins(
                color: const Color(0xff777b89),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Obx(() {
              final bool busy =
                  _authController.forgotPasswordSendingOtp.value;
              final bool canResend = _resendSeconds == 0 && !busy;

              return TextButton(
                onPressed: canResend ? () => _sendOtp(resend: true) : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  busy
                      ? ('Sending...').appTr
                      : _resendSeconds > 0
                      ? '${('Resend in').appTr} ${_resendSeconds}s'
                      : ('Resend').appTr,
                  style: GoogleFonts.poppins(
                    color: canResend
                        ? const Color(0xff7b42e8)
                        : const Color(0xff9a9da8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 17),
        Obx(
              () => _PrimaryActionButton(
            text: ('Verify code').appTr,
            icon: Icons.verified_rounded,
            loading: _authController.forgotPasswordVerifyingOtp.value,
            onPressed: _verifyOtp,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _changeEmail,
          icon: const Icon(Icons.edit_rounded, size: 17),
          label: Text(('Change email address').appTr),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xff666a77),
            textStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xff7b42e8) : const Color(0xffececf2),
          ),
          child: Text(
            number,
            style: GoogleFonts.poppins(
              color: active ? Colors.white : const Color(0xff9195a2),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: active ? const Color(0xff5f2fc0) : const Color(0xff9a9da8),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? const Color(0xff7b42e8) : const Color(0xffe4e4eb),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.textInputAction,
    required this.autofillHints,
    required this.onChanged,
    this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
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
          keyboardType: keyboardType,
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
              icon,
              color: hasError
                  ? const Color(0xffd83343)
                  : const Color(0xff7b42e8),
              size: 21,
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.text,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
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
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 9),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xff989ca8),
              fontSize: 11.2,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotPasswordBackgroundPainter extends CustomPainter {
  const _ForgotPasswordBackgroundPainter();

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
  bool shouldRepaint(covariant _ForgotPasswordBackgroundPainter oldDelegate) {
    return false;
  }
}
