import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:explore_my/presentation/navigation/main_page.dart';
import '../registration/registration_ui.dart';
import 'forgot_password_ui.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_profile/auth_provider.dart';
import '../../../providers/auth_profile/profile_provider.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kAccentOrange = Color(0xFFAB3510);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kTextBrown = Color(0xFF59413B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kIconTeal = Color(0xFF2F8F9D);

/// Pixel-accurate port of the Login screen design.
class LoginUi extends StatefulWidget {
  const LoginUi({super.key});

  @override
  State<LoginUi> createState() => _LoginUiState();
}

class _LoginUiState extends State<LoginUi> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  late final AnimationController _entranceController;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _formFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      await context
          .read<ProfileProvider>()
          .loadProfile(); // populate the cache once, right after login
      if (!mounted) return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Login failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgHeight = MediaQuery.of(context).size.height * 0.44;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: bgHeight,
              child: Image.asset(
                'assets/images/LoginBg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: FadeTransition(
                opacity: _formFade,
                child: SlideTransition(
                  position: _formSlide,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome back, explorer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _kTitleDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your next hidden place is waiting.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _kMuted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _InputField(
                            controller: _emailController,
                            hintText: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            leadingIcon: Icons.mail_outline,
                          ),
                          const SizedBox(height: 16),
                          _InputField(
                            controller: _passwordController,
                            hintText: 'Enter your password',
                            obscureText: _obscurePassword,
                            leadingIcon: Icons.lock_outline,
                            trailing: GestureDetector(
                              onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                              ),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFFCCCCCC),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _AnimatedTapText(
                              text: 'Forgot password?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kAccentOrange,
                                height: 16 / 13,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const ForgotPasswordUi(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _LoginButton(
                            onPressed: _onLogin,
                            isLoading: _isSubmitting,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "New to ExploreMy? ",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: _kTextBrown,
                                  height: 20 / 14,
                                ),
                              ),
                              _AnimatedTapText(
                                text: 'Create account',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kAccentOrange,
                                  height: 20 / 14,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const RegistrationUi(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text link with a press scale-down/bounce-back effect.
class _AnimatedTapText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  const _AnimatedTapText({
    required this.text,
    required this.style,
    required this.onTap,
  });

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

/// Recreates `.div` / `.background-border`: a labelled, bordered text field
/// with an optional leading icon.
class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.leadingIcon,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kInputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18, color: _kIconTeal),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: const Color(0xFF333333),
                height: 24 / 15,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFFCCCCCC),
                  height: 24 / 15,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Recreates `.primary-action-2` + `.button-shadow`: the solid orange Login
/// button with a soft drop shadow and a press-down/bounce-back click effect.
class _LoginButton extends StatefulWidget {
  const _LoginButton({required this.onPressed, this.isLoading = false});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _kPrimaryOrange,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Login',
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
      ),
    );
  }
}