import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:explore_my/presentation/navigation/main_page.dart';
import '../../../providers/auth_profile/auth_provider.dart';

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
  });

  final String email;
  final String topBarTitle;
  final String title;

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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Verification code is required';
    if (!RegExp(r'^\d{4,8}$').hasMatch(text)) return 'Enter a valid verification code';
    return null;
  }

  String? _errorMessage() =>
      widget.errorMessageOf?.call() ?? context.read<AuthProvider>().errorMessage;

  Future<void> _onVerifyCode() async {
    final codeError = _validateCode(_codeController.text);
    setState(() => _codeError = codeError);
    if (codeError != null) return;

    final code = _codeController.text.trim();
    final success = widget.onVerify != null
        ? await widget.onVerify!(code)
        : await context.read<AuthProvider>().verifyEmail(widget.email, code);

    if (!mounted) return;

    if (success) {
      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
              (route) => false,
        );
      }
    } else {
      _showStatusSnackBar(success: false, message: _errorMessage() ?? 'Verification failed.');
    }
  }

  Future<void> _onResendVerificationCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    final success = widget.onResend != null
        ? await widget.onResend!()
        : await context.read<AuthProvider>().resendVerificationCode(widget.email);

    if (!mounted) return;
    setState(() => _isResending = false);

    _showStatusSnackBar(
      success: success,
      message: success ? 'A new verification code has been sent.' : (_errorMessage() ?? 'Could not resend code.'),
    );
  }

  void _showStatusSnackBar({required bool success, required String message}) {
    final accentColor = success ? _kAccentOrange : const Color(0xFFD64545);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 4), blurRadius: 16),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(
                    success ? Icons.mark_email_read_outlined : Icons.error_outline,
                    size: 18,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextBrown),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                        textAlign: TextAlign.center,
                        onChanged: (value) => setState(() => _codeError = _validateCode(value)),
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
                    _PrimaryButton(label: 'Verify Email', onPressed: _onVerifyCode),
                    const SizedBox(height: 16),
                    _ResendCodeButton(
                      isLoading: _isResending,
                      onPressed: _onResendVerificationCode,
                    ),
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
                ),
              ),
            ),
          ],
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
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kPrimaryOrange,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 1), blurRadius: 2),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 24 / 16,
            ),
          ),
        ),
      ),
    );
  }
}