import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_profile/profile_provider.dart';
import '../../widgets/animated_tap_button.dart';
import '../../widgets/app_feedback.dart';
import '../authentication/registration/verify_email_ui.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kAccentOrange = Color(0xFFAB3510);
const Color _kFieldLabel = Color(0xFF59413B);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kChangePhotoColor = Color(0xFF555D7B);
const Color _kActionBorder = Color(0xFFF3B9AE);
const Color _kActionIconBg = Color(0x1AB41D0E);
const Color _kDangerBg = Color(0xFFFFDAD6);
const Color _kDangerText = Color(0xFFBA1A1A);
const Color _kSuccessBg = Color(0xFFD7F5DC);
const Color _kSuccessText = Color(0xFF1B7F3A);

class ManageProfileUi extends StatefulWidget {
  const ManageProfileUi({super.key});

  @override
  State<ManageProfileUi> createState() => _ManageProfileUiState();
}

class _ManageProfileUiState extends State<ManageProfileUi> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _ageController;
  late final TextEditingController _cityController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _selectedGender;
  String? _profilePictureUrl;
  bool _isUpdatingPhoto = false;
  bool _isSaving = false;
  bool _isRequestingEmailChange = false;
  bool _isRequestingCurrentEmailVerification = false;
  bool _currentEmailVerified = false;
  late String _verifiedEmail;
  String _originalUsername = '';
  String _originalAge = '';
  String _originalCity = '';
  String? _originalGender;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _ageController = TextEditingController(
      text: profile?.age?.toString() ?? '',
    );
    _cityController = TextEditingController(text: profile?.city ?? '');
    _selectedGender = profile?.gender;
    _profilePictureUrl = profile?.profilePictureUrl;
    _verifiedEmail = profile?.email ?? '';
    _originalUsername = _usernameController.text;
    _originalAge = _ageController.text;
    _originalCity = _cityController.text;
    _originalGender = _selectedGender;
  }

  bool get _hasChanges =>
      _usernameController.text.trim() != _originalUsername.trim() ||
      _ageController.text.trim() != _originalAge.trim() ||
      _cityController.text.trim() != _originalCity.trim() ||
      _selectedGender != _originalGender;

  /// [_hasChanges] plus an in-progress (unverified) email edit, which the
  /// Save Changes button doesn't cover but leaving the page would still lose.
  bool get _hasUnsavedChanges =>
      _hasChanges || _emailController.text.trim() != _verifiedEmail.trim();

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard changes?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTitleDark,
          ),
        ),
        content: Text(
          'You have unsaved changes to your profile. If you leave now, they will be lost.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep Editing',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Discard',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kDangerText,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// UC103 A3-4 step 3 — leaving the Change Email flow invalidates any code
  /// that was issued for it, so a stale code can't be replayed later.
  Future<void> _cancelPendingEmailChange() async {
    final hasPendingEmailChange = _currentEmailVerified ||
        _emailController.text.trim() != _verifiedEmail.trim();
    if (!hasPendingEmailChange) return;

    await context.read<ProfileProvider>().cancelEmailChange();
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      await _cancelPendingEmailChange();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    final shouldDiscard = await _confirmDiscardChanges();
    if (!shouldDiscard || !mounted) return;

    await _cancelPendingEmailChange();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickGender() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const ['Male', 'Female', 'Prefer not to say'])
              ListTile(
                title: Text(option, style: GoogleFonts.plusJakartaSans()),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedGender = result);
    }
  }

  /// UC103 C2 — profile information validation. Returns the first problem
  /// found, or null when every field is acceptable.
  String? _validateProfile() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return 'Username is required.';
    if (username.length < 3 || username.length > 30) {
      return 'Username must be 3-30 characters.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(username)) {
      return 'Username contains invalid characters.';
    }

    // City, age and gender are optional — the profile saves with any of them
    // blank, and clearing one is how the user removes it. Age is still checked
    // for shape, but only when something was actually typed.
    final ageText = _ageController.text.trim();
    if (ageText.isNotEmpty) {
      final age = int.tryParse(ageText);
      if (age == null) return 'Enter a valid age.';
      if (age < 13 || age > 120) return 'Age must be between 13 and 120.';
    }

    return null;
  }

  Future<void> _onSaveChanges() async {
    final validationError = _validateProfile();
    if (validationError != null) {
      // A1-1: report the problem and keep everything the user typed.
      AppFeedback.show(context, message: validationError, isSuccess: false);
      return;
    }

    final username = _usernameController.text.trim();
    final ageText = _ageController.text.trim();
    // Null rather than 0/"" for a blank optional field, so the backend clears
    // the column instead of storing a placeholder.
    final age = ageText.isEmpty ? null : int.parse(ageText);

    setState(() => _isSaving = true);
    final profileProvider = context.read<ProfileProvider>();
    final city = _cityController.text.trim();
    final success = await profileProvider.updateProfile(
      username: username,
      city: city.isEmpty ? null : city,
      age: age,
      gender: (_selectedGender != null && _selectedGender!.isEmpty)
          ? null
          : _selectedGender,
    );
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (success) {
        _originalUsername = username;
        _originalAge = ageText;
        _originalCity = city;
        _originalGender = _selectedGender;
      }
    });
    AppFeedback.show(
      context,
      message: success
          ? 'Profile updated successfully.'
          : (profileProvider.errorMessage ??
                'Failed to update your profile. Please try again.'),
      isSuccess: success,
    );
  }

  String? _validateEmail(String value) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _showEmailStatus(String message, {required bool isSuccess}) {
    final background = isSuccess ? _kSuccessBg : _kDangerBg;
    final foreground = isSuccess ? _kSuccessText : _kDangerText;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onVerifyCurrentEmail() async {
    setState(() => _isRequestingCurrentEmailVerification = true);
    final profileProvider = context.read<ProfileProvider>();
    final requested = await profileProvider.requestCurrentEmailVerification();
    if (!mounted) return;
    setState(() => _isRequestingCurrentEmailVerification = false);

    if (!requested) {
      _showEmailStatus(
        profileProvider.errorMessage ?? 'Could not send verification code.',
        isSuccess: false,
      );
      return;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailUi(
          email: _verifiedEmail,
          topBarTitle: 'Manage Profile',
          title: 'Verify Current Email',
          description:
              "We've sent a verification code to $_verifiedEmail. Enter it below to confirm it's you before changing your email.",
          onVerify: (code) => context
              .read<ProfileProvider>()
              .verifyCurrentEmailVerification(code),
          onResend: () =>
              context.read<ProfileProvider>().requestCurrentEmailVerification(),
          errorMessageOf: () => context.read<ProfileProvider>().errorMessage,
          onVerified: () => Navigator.of(context).pop(true),
          showChangeEmailLink: false,
        ),
      ),
    );

    if (verified == true && mounted) {
      setState(() => _currentEmailVerified = true);
      _showEmailStatus('Current email verified.', isSuccess: true);
    }
  }

  Future<void> _onVerifyNewEmail(String newEmail) async {
    final emailError = _validateEmail(newEmail);
    if (emailError != null) {
      _showEmailStatus(emailError, isSuccess: false);
      return;
    }

    setState(() => _isRequestingEmailChange = true);
    final profileProvider = context.read<ProfileProvider>();
    final requested = await profileProvider.requestEmailChange(newEmail);
    if (!mounted) return;
    setState(() => _isRequestingEmailChange = false);

    if (!requested) {
      _showEmailStatus(
        profileProvider.errorMessage ?? 'Could not send verification code.',
        isSuccess: false,
      );
      return;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailUi(
          email: newEmail,
          topBarTitle: 'Manage Profile',
          title: 'Verify New Email',
          description:
              "We've sent a verification code to $newEmail. Enter it below to confirm your new email address.",
          onVerify: (code) =>
              context.read<ProfileProvider>().verifyEmailChange(newEmail, code),
          onResend: () =>
              context.read<ProfileProvider>().requestEmailChange(newEmail),
          errorMessageOf: () => context.read<ProfileProvider>().errorMessage,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (verified == true && mounted) {
      setState(() {
        _verifiedEmail = newEmail;
        _currentEmailVerified = false;
      });
      _showEmailStatus('Email updated successfully.', isSuccess: true);
    }
  }

  void _showProfilePhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfilePhotoSheet(
        onTakePhoto: () => _pickAndUploadImage(ImageSource.camera),
        onChooseFromGallery: () => _pickAndUploadImage(ImageSource.gallery),
        onRemovePhoto: _removePhoto,
        hasPhoto: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty,
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUpdatingPhoto = true);
    final success = await context.read<ProfileProvider>().updateProfilePicture(
      File(picked.path),
    );
    if (!mounted) return;

    setState(() {
      _isUpdatingPhoto = false;
      if (success) {
        _profilePictureUrl = context
            .read<ProfileProvider>()
            .profile
            ?.profilePictureUrl;
      }
    });

    if (!success) {
      AppFeedback.show(context,
          message: 'Failed to update profile photo.', isSuccess: false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUpdatingPhoto = true);
    final success = await context
        .read<ProfileProvider>()
        .removeProfilePicture();
    if (!mounted) return;

    setState(() {
      _isUpdatingPhoto = false;
      if (success) _profilePictureUrl = null;
    });

    if (!success) {
      AppFeedback.show(context,
          message: 'Failed to remove profile photo.', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Locally cached copy when there is one, remote URL otherwise. Watched so
    // the picture refreshes as soon as a new upload finishes downloading.
    final avatarImage = context.watch<ProfileProvider>().avatarImage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: _handleBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedTapButton(
                              onTap: _isUpdatingPhoto
                                  ? null
                                  : _showProfilePhotoOptions,
                              borderRadius: BorderRadius.circular(60),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    avatarImage != null
                                        ? Transform.scale(
                                            scale: 1.2,
                                            child: Image(
                                              image: avatarImage,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    color: const Color(
                                                      0xFFDDE9FF,
                                                    ),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 64,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFFDDE9FF),
                                            child: const Icon(
                                              Icons.person,
                                              size: 72,
                                              color: Colors.white,
                                            ),
                                          ),
                                    if (_isUpdatingPhoto)
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: AnimatedTapButton(
                                onTap: _isUpdatingPhoto
                                    ? null
                                    : _showProfilePhotoOptions,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _kPrimaryOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: AnimatedTapButton(
                          onTap: _isUpdatingPhoto
                              ? null
                              : _showProfilePhotoOptions,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              'Change Profile Photo',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _kChangePhotoColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _FieldLabel('Username'),
                      const SizedBox(height: 8),
                      _ProfileField(
                        controller: _usernameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      const _FieldLabel('Email Address'),
                      const SizedBox(height: 8),
                      _ProfileField(
                        controller: _emailController,
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: !_currentEmailVerified,
                      ),
                      if (!_currentEmailVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AnimatedTapButton(
                            onTap: _isRequestingCurrentEmailVerification
                                ? null
                                : _onVerifyCurrentEmail,
                            borderRadius: BorderRadius.circular(9999),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _kPrimaryOrange),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              alignment: Alignment.center,
                              child: _isRequestingCurrentEmailVerification
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _kPrimaryOrange,
                                      ),
                                    )
                                  : Text(
                                      'Verify Current Email to Change',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _kPrimaryOrange,
                                      ),
                                    ),
                            ),
                          ),
                        )
                      else
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _emailController,
                          builder: (context, value, _) {
                            final newEmail = value.text.trim();
                            final changed =
                                newEmail.isNotEmpty &&
                                newEmail != _verifiedEmail;
                            if (!changed) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AnimatedTapButton(
                                onTap: _isRequestingEmailChange
                                    ? null
                                    : () => _onVerifyNewEmail(newEmail),
                                borderRadius: BorderRadius.circular(9999),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _kPrimaryOrange),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isRequestingEmailChange
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _kPrimaryOrange,
                                          ),
                                        )
                                      : Text(
                                          'Verify New Email',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _kPrimaryOrange,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Age'),
                                const SizedBox(height: 8),
                                _ProfileField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Gender'),
                                const SizedBox(height: 8),
                                _GenderField(
                                  value: _selectedGender,
                                  onTap: _pickGender,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _FieldLabel('City'),
                      const SizedBox(height: 8),
                      _ProfileField(
                        controller: _cityController,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _usernameController,
                          _ageController,
                          _cityController,
                        ]),
                        builder: (context, _) {
                          if (!_hasChanges) return const SizedBox.shrink();
                          return _SaveChangesButton(
                            onPressed: _isSaving ? null : _onSaveChanges,
                            isLoading: _isSaving,
                          );
                        },
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
          AnimatedTapButton(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: _kAccentOrange, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Manage Profile',
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

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _kFieldLabel,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool readOnly;

  const _ProfileField({
    required this.controller,
    this.icon,
    this.keyboardType,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFFF5F6F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kInputBorder),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: _kMuted),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: readOnly ? _kMuted : _kTitleDark,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderField extends StatelessWidget {
  final String? value;
  final VoidCallback onTap;

  const _GenderField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kInputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? 'Select',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: _kTitleDark,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

class _SaveChangesButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SaveChangesButton({required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _kPrimaryOrange,
          borderRadius: BorderRadius.circular(9999),
        ),
        alignment: Alignment.center,
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
                'Save Changes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _ProfilePhotoSheet extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromGallery;
  final VoidCallback onRemovePhoto;
  final bool hasPhoto;

  const _ProfilePhotoSheet({
    required this.onTakePhoto,
    required this.onChooseFromGallery,
    required this.onRemovePhoto,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kActionBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile Photo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kTitleDark,
                    ),
                  ),
                ),
                AnimatedTapButton(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 22, color: _kTitleDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _kInputBorder),
            const SizedBox(height: 20),
            _PhotoOptionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () {
                Navigator.of(context).pop();
                onTakePhoto();
              },
            ),
            const SizedBox(height: 12),
            _PhotoOptionTile(
              icon: Icons.image_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.of(context).pop();
                onChooseFromGallery();
              },
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: _kInputBorder),
              const SizedBox(height: 16),
              _RemovePhotoTile(
                onTap: () {
                  Navigator.of(context).pop();
                  onRemovePhoto();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kActionBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kActionIconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: _kPrimaryOrange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _kTitleDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

class _RemovePhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _RemovePhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kDangerBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 20,
                color: _kDangerText,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Remove Current Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kDangerText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
