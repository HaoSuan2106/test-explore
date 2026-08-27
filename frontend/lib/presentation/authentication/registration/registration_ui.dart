import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_profile/auth_provider.dart';
import '../../../utilities/password_policy.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';
import '../../../widgets/password_requirements.dart';
import 'verify_email_ui.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kAccentOrange = Color(0xFFAB3510);
const Color _kTextBrown = Color(0xFF59413B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kPlaceholderGray = Color(0xFF6B7280);
const Color _kIconGray = Color(0xFF727880);

class RegistrationUi extends StatefulWidget {
  const RegistrationUi({super.key});

  @override
  State<RegistrationUi> createState() => _RegistrationUiState();
}

class _RegistrationUiState extends State<RegistrationUi> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final usernameError = _validateUsername(_usernameController.text);
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);

    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });

    final isFormValid = usernameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null;

    if (!isFormValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerifyEmailUi(email: _emailController.text.trim())),
      );
    } else {
      AppFeedback.show(context,
          message: authProvider.errorMessage ?? 'Registration failed.', isSuccess: false);
    }
  }

  String? _validateUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Username is required';
    if (text.length < 3 || text.length > 30) return 'Username must be 3-30 characters';
    if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(text)) return 'Username contains invalid characters';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (text.contains(' ')) return 'Email must not contain spaces';
    if ('@'.allMatches(text).length != 1) return 'Email must contain exactly one @';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    return PasswordPolicy.validationError(value);
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentConstraint(
        maxWidth: 600,
        child: Stack(
          children: [
            const Positioned.fill(child: _MapPinsBackground()),
            SafeArea(
              child: Column(
                children: [
                _TopBar(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    Text(
                      'Create Account',
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
                      'Join our community of explorers and start your adventure.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _kTextBrown,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _RegField(
                      label: 'Username',
                      controller: _usernameController,
                      hintText: 'Choose a travel alias',
                      icon: Icons.person_outline,
                      errorText: _usernameError,
                      onChanged: (value) => setState(() => _usernameError = _validateUsername(value)),
                    ),
                    const SizedBox(height: 16),
                    _RegField(
                      label: 'Email Address',
                      controller: _emailController,
                      hintText: 'yourname@example.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: (value) => setState(() => _emailError = _validateEmail(value)),
                    ),
                    const SizedBox(height: 16),
                    _RegField(
                      label: 'Password',
                      controller: _passwordController,
                      hintText: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      errorText: _passwordError,
                      onChanged: (value) => setState(() {
                        _passwordError = _validatePassword(value);
                        if (_confirmPasswordController.text.isNotEmpty) {
                          _confirmPasswordError = _validateConfirmPassword(
                            _confirmPasswordController.text,
                          );
                        }
                      }),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: _kIconGray,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PasswordRequirements(password: _passwordController.text),
                    const SizedBox(height: 16),
                    _RegField(
                      label: 'Confirm Password',
                      controller: _confirmPasswordController,
                      hintText: '••••••••',
                      icon: Icons.verified_user_outlined,
                      obscureText: _obscureConfirmPassword,
                      errorText: _confirmPasswordError,
                      onChanged: (value) => setState(() => _confirmPasswordError = _validateConfirmPassword(value)),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        child: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: _kIconGray,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ContinueButton(onPressed: _onContinue, isLoading: _isSubmitting),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _kTextBrown,
                            height: 20 / 14,
                          ),
                        ),
                        _AnimatedTapText(
                          text: 'Back to Login',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kAccentOrange,
                            height: 20 / 14,
                          ),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          );
                },
              ),
            ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// A quiet backdrop of map pins that fade/scale in at random spots, hold
/// briefly, then fade out and reappear elsewhere — echoing the "hidden
/// locations" motif in the ExploreMy logo.
class _MapPinsBackground extends StatefulWidget {
  const _MapPinsBackground();

  @override
  State<_MapPinsBackground> createState() => _MapPinsBackgroundState();
}

class _Pin {
  _Pin({required this.controller, required this.dx, required this.dy, required this.color, required this.scale});

  final AnimationController controller;
  double dx;
  double dy;
  Color color;
  double scale;
}

class _MapPinsBackgroundState extends State<_MapPinsBackground>
    with TickerProviderStateMixin {
  static const _pinColors = [
    Color(0xFFFF7148), // orange, matches the primary button
    Color(0xFF2F8F9D), // teal, matches the magnifying glass
    Color(0xFFF5B942), // gold, matches the logo's star
    Color(0xFF1B4F72), // navy, matches the pin/magnifier outline
  ];

  final _random = math.Random();
  final List<_Pin> _pins = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 16; i++) {
      _pins.add(_spawnPin(initialDelay: i * 200));
    }
  }

  _Pin _spawnPin({int initialDelay = 0}) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300 + _random.nextInt(800)),
    );
    final pin = _Pin(
      controller: controller,
      dx: _random.nextDouble(),
      dy: _random.nextDouble(),
      color: _pinColors[_random.nextInt(_pinColors.length)],
      scale: 0.7 + _random.nextDouble() * 0.6,
    );

    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      Future.delayed(
        Duration(milliseconds: 150 + _random.nextInt(700)),
        () {
          if (!mounted) return;
          setState(() {
            pin.dx = _random.nextDouble();
            pin.dy = _random.nextDouble();
            pin.color = _pinColors[_random.nextInt(_pinColors.length)];
            pin.scale = 0.7 + _random.nextDouble() * 0.6;
          });
          controller.forward(from: 0);
        },
      );
    });

    Future.delayed(Duration(milliseconds: initialDelay), () {
      if (mounted) controller.forward(from: 0);
    });

    return pin;
  }

  @override
  void dispose() {
    for (final pin in _pins) {
      pin.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: _pins.map((pin) {
                return AnimatedBuilder(
                  animation: pin.controller,
                  builder: (context, child) {
                    final t = pin.controller.value;
                    final appear = Curves.easeOutBack.transform(
                      (t / 0.35).clamp(0.0, 1.0),
                    );
                    final disappear = t < 0.7
                        ? 1.0
                        : 1.0 -
                            Curves.easeIn.transform(
                              ((t - 0.7) / 0.3).clamp(0.0, 1.0),
                            );
                    final opacity = (appear * disappear).clamp(0.0, 1.0);
                    final scale = appear * pin.scale;

                    return Positioned(
                      left: pin.dx * constraints.maxWidth - 14,
                      top: pin.dy * constraints.maxHeight - 14,
                      child: Opacity(
                        opacity: opacity * 0.35,
                        child: Transform.scale(
                          scale: scale,
                          child: Icon(
                            Icons.location_on,
                            color: pin.color,
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
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
            'Login',
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

class _RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _RegField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.trailing,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kTextBrown,
              height: 18 / 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: errorText != null ? Colors.red : _kInputBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kIconGray),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kPlaceholderGray),
                  ),
                ),
              ),
              ?trailing,
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

class _ContinueButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _ContinueButton({required this.onPressed, required this.isLoading});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: disabled ? null : widget.onPressed,
          onHighlightChanged: disabled ? null : (isHighlighted) => setState(() => _isPressed = isHighlighted),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kPrimaryOrange,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 1), blurRadius: 2),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 18 / 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedTapText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  const _AnimatedTapText({required this.text, required this.style, required this.onTap});

  @override
  State<_AnimatedTapText> createState() => _AnimatedTapTextState();
}

class _AnimatedTapTextState extends State<_AnimatedTapText> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: Duration(milliseconds: _isPressed ? 80 : 200),
        curve: _isPressed ? Curves.easeOut : Curves.easeOutBack,
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
