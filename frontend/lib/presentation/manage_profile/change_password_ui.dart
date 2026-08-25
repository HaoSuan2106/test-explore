import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_profile/profile_provider.dart';
import '../authentication/registration/verify_email_ui.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kAccentOrange = Color(0xFFAB3510);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kDisabledBg = Color(0xFFE5E7EB);

class ChangePasswordUi extends StatefulWidget {
  const ChangePasswordUi({super.key});

  @override
  State<ChangePasswordUi> createState() => _ChangePasswordUiState();
}

class _ChangePasswordUiState extends State<ChangePasswordUi> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVerified = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isNewPasswordValid {
    final text = _newPasswordController.text;
    final hasMinLength = text.length >= 8;
    final hasNumber = RegExp(r'\d').hasMatch(text);
    final hasSymbol = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`\[\];/]').hasMatch(text);
    return hasMinLength && hasNumber && hasSymbol;
  }

  bool get _doPasswordsMatch =>
      _confirmPasswordController.text.isNotEmpty && _confirmPasswordController.text == _newPasswordController.text;

  bool get _canUpdate => _isCurrentPasswordVerified && _isNewPasswordValid && _doPasswordsMatch;

  void _onCheckCurrentPassword() {
    // TODO: wire up to the check-current-password API.
    setState(() => _isCurrentPasswordVerified = true);
  }

  void _onUpdatePassword() {
    if (!_canUpdate) return;
    // TODO: wire up to the update-password API.
  }

  Future<void> _onResetViaEmail() async {
    final email = context.read<ProfileProvider>().profile?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find your account email.')),
      );
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final requested = await profileProvider.requestPasswordResetCode();
    if (!mounted) return;

    if (!requested) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileProvider.errorMessage ?? 'Could not send verification code.')),
      );
      return;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailUi(
          email: email,
          topBarTitle: 'Change Password',
          title: 'Verify Your Identity',
          description: "We've sent a verification code to $email. Enter it below to reset your password.",
          onVerify: (code) => context.read<ProfileProvider>().verifyPasswordResetCode(code),
          onResend: () => context.read<ProfileProvider>().requestPasswordResetCode(),
          errorMessageOf: () => context.read<ProfileProvider>().errorMessage,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (verified == true && mounted) {
      setState(() => _isCurrentPasswordVerified = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Please enter your current password and choose a new, secure one to protect your account.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _kMuted,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Current Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kTitleDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PasswordField(
                      controller: _currentPasswordController,
                      hintText: 'Enter current password',
                      onChanged: (_) => setState(() {
                        if (_isCurrentPasswordVerified) {
                          _isCurrentPasswordVerified = false;
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        }
                      }),
                    ),
                    const SizedBox(height: 20),
                    _CheckButton(onPressed: _onCheckCurrentPassword),
                    const SizedBox(height: 40),
                    Divider(height: 1, color: _kInputBorder),
                    const SizedBox(height: 40),
                    Text(
                      'New Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kTitleDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PasswordField(
                      controller: _newPasswordController,
                      hintText: 'Min. 8 characters',
                      enabled: _isCurrentPasswordVerified,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: _kMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'At least 8 characters, include a number and a symbol.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _kMuted,
                              height: 16 / 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Confirm New Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kTitleDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PasswordField(
                      controller: _confirmPasswordController,
                      hintText: 'Re-enter new password',
                      enabled: _isCurrentPasswordVerified,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 40),
                    _UpdatePasswordButton(enabled: _canUpdate, onPressed: _onUpdatePassword),
                    const SizedBox(height: 16),
                    _CancelButton(onPressed: () => Navigator.of(context).pop()),
                    const SizedBox(height: 36),
                    Center(
                      child: Text(
                        'Secure encryption is used to protect your credentials.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted, height: 16 / 12),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(
                            'Lost your current password? ',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted, height: 16 / 12),
                          ),
                          GestureDetector(
                            onTap: _onResetViaEmail,
                            child: Text(
                              'Reset via Email',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kAccentOrange,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                        ],
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
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

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
            'Change Password',
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

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.hintText,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: _kInputBorder),
    );
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kTitleDark),
      decoration: InputDecoration(
        filled: true,
        fillColor: widget.enabled ? Colors.white : _kDisabledBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintText: widget.hintText,
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kMuted),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: _kPrimaryOrange)),
        suffixIcon: GestureDetector(
          onTap: widget.enabled ? () => setState(() => _obscure = !_obscure) : null,
          child: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: _kMuted,
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CheckButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: _kPrimaryOrange, borderRadius: BorderRadius.circular(9999)),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Check',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified_outlined, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdatePasswordButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _UpdatePasswordButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled ? _kPrimaryOrange : _kDisabledBg;
    final foregroundColor = enabled ? Colors.white : _kMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(9999)),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Update Password',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: foregroundColor),
              ),
              const SizedBox(width: 8),
              Icon(Icons.check_circle_outline, size: 18, color: foregroundColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CancelButton({required this.onPressed});

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: _kInputBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: _kMuted),
          ),
        ),
      ),
    );
  }
}
