import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_profile/auth_provider.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kAccentOrange = Color(0xFFAB3510);
const Color _kTextBrown = Color(0xFF59413B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kChangeEmailColor = Color(0xFF555D7B);

class VerifyEmailUi extends StatefulWidget {
  const VerifyEmailUi({
    super.key,
    required this.email,
    this.topBarTitle = 'Register',
    this.title = 'Verify Your Email',
    this.description,
    this.onVerify,
    this.onResend,
    this.onVerified,
    this.errorMessageOf,
    this.showChangeEmailLink = true,
  });

  final String email;
  final String topBarTitle;
  final String title;

  /// Whether to show the "Change Email" link that pops back to edit the
  /// address. Set to false when [email] isn't editable from here (e.g.
  /// verifying the caller's current email before an email change).
  final bool showChangeEmailLink;

  /// Defaults to the registration-flow copy when null.
  final String? description;

  /// Overrides how a code is verified. Defaults to [AuthProvider.verifyEmail]
  /// (the registration flow) when null.
  final Future<bool> Function(String code)? onVerify;

  /// Overrides how a code is resent. Defaults to
  /// [AuthProvider.resendVerificationCode] when null.
  final Future<bool> Function()? onResend;

  /// Called instead of navigating to [MainPage] when verification succeeds.
  final VoidCallback? onVerified;

  /// Overrides the error message shown on failure. Defaults to
  /// [AuthProvider.errorMessage] when null.
  final String? Function()? errorMessageOf;

  @override
  State<VerifyEmailUi> createState() => _VerifyEmailUiState();
}

class _VerifyEmailUiState extends State<VerifyEmailUi> {
  final _codeController = TextEditingController();
  String? _codeError;
  bool _isResending = false;
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// FR101-10 / FR102-14: verification codes are exactly six digits.
  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Verification code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(text)) {
      return 'Enter the 6-digit verification code';
    }
    return null;
  }

  String? _errorMessage() =>
      widget.errorMessageOf?.call() ?? context.read<AuthProvider>().errorMessage;

  Future<void> _onVerifyCode() async {
    if (_isVerifying) return;

    final codeError = _validateCode(_codeController.text);
    setState(() => _codeError = codeError);
    if (codeError != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isVerifying = true);

    // Captured before the success toast's pause so it survives the async gap
    // even as this route is being torn down.
    final navigator = Navigator.of(context);

    final code = _codeController.text.trim();
    var success = false;
    try {
      success = widget.onVerify != null
          ? await widget.onVerify!(code)
          : await context.read<AuthProvider>().verifyEmail(widget.email, code);
    } finally {
      // On success the button stays in its loading state until we navigate
      // away, so the code can't be submitted a second time during the pause.
      if (mounted && !success) setState(() => _isVerifying = false);
    }

    if (!mounted) return;

    if (!success) {
      AppFeedback.show(context,
          message: _errorMessage() ?? 'Verification failed.', isSuccess: false);
      return;
    }

    if (widget.onVerified != null) {
      setState(() => _isVerifying = false);
      widget.onVerified!();
      return;
    }

    // FR101 registration flow: confirm the account is created, then hand the
    // user back to Login to sign in with it.
    AppFeedback.show(context,
        message: 'Registration successful! Please log in to continue.');

    // The toast lives in the root overlay, so it stays on screen across the
    // route change — this pause just lets it land here before Login appears.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Register and Verify were pushed imperatively (plain Navigator.push) on
    // top of the /login page, so the router's location never left /login —
    // popping those two routes is what actually reveals Login again. Don't
    // also go('/login'): rebuilding the page stack underneath routes that are
    // being removed is what left the screen black.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _onResendVerificationCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    final success = widget.onResend != null
        ? await widget.onResend!()
        : await context.read<AuthProvider>().resendVerificationCode(widget.email);

    if (!mounted) return;
    setState(() => _isResending = false);

    AppFeedback.show(
      context,
      message: success
          ? 'A new verification code has been sent.'
          : (_errorMessage() ?? 'Could not resend code.'),
      isSuccess: success,
    );
  }

  void _onChangeEmail() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 600,
          child: Column(
            children: [
              _TopBar(title: widget.topBarTitle, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 192,
                        height: 192,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: _kInputBorder),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _kPrimaryOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.mail_outline, size: 36, color: _kAccentOrange),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Dot(opacity: 0.2),
                                const SizedBox(width: 4),
                                _Dot(opacity: 0.4),
                                const SizedBox(width: 4),
                                _Dot(opacity: 0.6),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kPrimaryOrange,
                        height: 24 / 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description ??
                          "We've sent a verification code to ${widget.email}. Please enter the code to complete your registration.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _kTextBrown,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCFCFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _codeError != null ? Colors.red : _kInputBorder),
                      ),
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textAlign: TextAlign.center,
                        onChanged: (value) => setState(() => _codeError = _validateCode(value)),
                        onSubmitted: (_) => _onVerifyCode(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          letterSpacing: 8,
                          color: _kTextBrown,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: InputBorder.none,
                          hintText: 'Enter Verification Code',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            letterSpacing: 0,
                            color: _kTextBrown.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    if (_codeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _codeError!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _PrimaryButton(
                      label: 'Verify Email',
                      isLoading: _isVerifying,
                      onPressed: _isVerifying ? null : _onVerifyCode,
                    ),
                    const SizedBox(height: 16),
                    _ResendCodeButton(
                      isLoading: _isResending,
                      onPressed: _onResendVerificationCode,
                    ),
                    if (widget.showChangeEmailLink) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _onChangeEmail,
                          child: Text(
                            'Change Email',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kChangeEmailColor,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                      ),
                    ],
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
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back, color: _kAccentOrange, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _kAccentOrange,
              height: 24 / 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double opacity;

  const _Dot({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _kAccentOrange.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ResendCodeButton extends StatefulWidget {
  const _ResendCodeButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<_ResendCodeButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(9999));
    final disabled = widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: Duration(milliseconds: _isPressed ? 80 : 250),
        curve: _isPressed ? Curves.easeOut : Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: disabled ? null : widget.onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: _kAccentOrange),
              ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kAccentOrange),
                    )
                  : Text(
                      'Resend Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kAccentOrange,
                        height: 20 / 14,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: _kPrimaryOrange,
          disabledBackgroundColor: _kPrimaryOrange.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 24 / 16,
                ),
              ),
      ),
    );
  }
}