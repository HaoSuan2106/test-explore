import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_profile/auth_provider.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';
import '../registration/verify_email_ui.dart';
import 'reset_password_ui.dart';

const Color _kHeadingColor = Color(0xFF111827);
const Color _kSubtitleColor = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFDCE3ED);
const Color _kFieldBackground = Color(0xFFF9FAFB);
const Color _kFieldBorder = Color(0xFFE5E7EB);
const Color _kIconColor = Color(0xFF9CA3AF);
const Color _kPrimaryOrange = Color(0xFFFF7148);

class ForgotPasswordUi extends StatefulWidget {
  final String backLabel;

  const ForgotPasswordUi({super.key, this.backLabel = 'Back to Login'});

  @override
  State<ForgotPasswordUi> createState() => _ForgotPasswordUiState();
}

class _ForgotPasswordUiState extends State<ForgotPasswordUi> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (text.contains(' ')) return 'Email must not contain spaces';
    if ('@'.allMatches(text).length != 1) return 'Email must contain exactly one @';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  /// UC102 FR102-13/FR102-14 — request a reset code, then walk the user
  /// through verifying it and choosing a new password.
  Future<void> _onResetPassword() async {
    if (_isSubmitting) return;

    final error = _validateEmail(_emailController.text);
    setState(() => _emailError = error);
    if (error != null) return;

    final email = _emailController.text.trim();
    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
    final requested = await authProvider.requestPasswordReset(email);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!requested) {
      AppFeedback.show(
        context,
        message: authProvider.errorMessage ?? 'Could not send the reset code.',
        isSuccess: false,
      );
      return;
    }

    // The backend answers the same way whether or not the address has an
    // account, so the wording here must not imply one exists.
    AppFeedback.show(
      context,
      message: 'If an account exists for that email, a reset code has been sent.',
    );

    var verifiedCode = '';
    final codeVerified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailUi(
          email: email,
          topBarTitle: 'Reset Password',
          title: 'Check Your Email',
          description:
              "If an account exists for $email, we've sent it a 6-digit code. "
              'Enter it below to reset your password.',
          showChangeEmailLink: false,
          onVerify: (code) async {
            final ok = await context
                .read<AuthProvider>()
                .verifyPasswordResetCode(email, code);
            if (ok) verifiedCode = code;
            return ok;
          },
          onResend: () =>
              context.read<AuthProvider>().requestPasswordReset(email),
          errorMessageOf: () => context.read<AuthProvider>().errorMessage,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (codeVerified != true || !mounted) return;

    final didReset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResetPasswordUi(email: email, code: verifiedCode),
      ),
    );

    // FR102-22: back to the Login page once the password has been updated.
    if (didReset == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 600,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kCardBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 4), blurRadius: 12),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Forgot Password?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kHeadingColor,
                      height: 28 / 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your email address and we'll send you a 6-digit code to reset your password.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _kSubtitleColor,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        'Email Address',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kHeadingColor,
                          height: 18 / 14,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '*',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kPrimaryOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _kFieldBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _emailError != null ? Colors.red : _kFieldBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 18, color: _kIconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) => setState(() => _emailError = _validateEmail(value)),
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kHeadingColor),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: InputBorder.none,
                              hintText: 'Enter your email',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kIconColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _emailError!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _isSubmitting ? null : _onResetPassword,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _kPrimaryOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Reset Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 24 / 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 16, color: _kHeadingColor),
                          const SizedBox(width: 6),
                          Text(
                            widget.backLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kHeadingColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
