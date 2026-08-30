import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_profile/auth_provider.dart';
import '../../../utilities/password_policy.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';
import '../../../widgets/password_requirements.dart';

const Color _kHeadingColor = Color(0xFF111827);
const Color _kSubtitleColor = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFDCE3ED);
const Color _kFieldBackground = Color(0xFFF9FAFB);
const Color _kFieldBorder = Color(0xFFE5E7EB);
const Color _kIconColor = Color(0xFF9CA3AF);
const Color _kPrimaryOrange = Color(0xFFFF7148);

/// Final step of the signed-out password reset (UC102 FR102-18..FR102-22):
/// the emailed code has already been verified, so the user may now choose a
/// new password. Popping with `true` tells the caller the reset succeeded.
class ResetPasswordUi extends StatefulWidget {
  const ResetPasswordUi({super.key, required this.email, required this.code});

  final String email;

  /// The reset code that was just verified — re-checked server-side before the
  /// password is stored, and only marked used afterwards (FR102-20/21).
  final String code;

  @override
  State<ResetPasswordUi> createState() => _ResetPasswordUiState();
}

class _ResetPasswordUiState extends State<ResetPasswordUi> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _passwordError;
  String? _confirmPasswordError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your new password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;

    final passwordError = PasswordPolicy.validationError(_passwordController.text);
    final confirmPasswordError =
        _validateConfirmPassword(_confirmPasswordController.text);

    setState(() {
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });

    if (passwordError != null || confirmPasswordError != null) return;

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      email: widget.email,
      code: widget.code,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      AppFeedback.show(context, message: 'Password reset successfully.');
      Navigator.of(context).pop(true);
    } else {
      AppFeedback.show(
        context,
        message: authProvider.errorMessage ?? 'Could not reset your password.',
        isSuccess: false,
      );
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
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Set a New Password',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kHeadingColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a new password for ${widget.email}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _kSubtitleColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PasswordField(
                      label: 'New Password',
                      controller: _passwordController,
                      hintText: 'Enter your new password',
                      obscureText: _obscurePassword,
                      errorText: _passwordError,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onChanged: (value) => setState(() {
                        _passwordError = PasswordPolicy.validationError(value);
                        if (_confirmPasswordController.text.isNotEmpty) {
                          _confirmPasswordError =
                              _validateConfirmPassword(_confirmPasswordController.text);
                        }
                      }),
                    ),
                    const SizedBox(height: 8),
                    PasswordRequirements(password: _passwordController.text),
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: 'Confirm New Password',
                      controller: _confirmPasswordController,
                      hintText: 'Re-enter your new password',
                      obscureText: _obscureConfirmPassword,
                      errorText: _confirmPasswordError,
                      onToggleObscure: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword),
                      onChanged: (value) => setState(
                          () => _confirmPasswordError = _validateConfirmPassword(value)),
                    ),
                    const SizedBox(height: 24),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isSubmitting ? null : _onSubmit,
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
                                  'Update Password',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggleObscure,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kHeadingColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kFieldBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null ? Colors.red : _kFieldBorder,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: _kIconColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  onChanged: onChanged,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: _kHeadingColor,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: _kIconColor,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: _kIconColor,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText!,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }
}
