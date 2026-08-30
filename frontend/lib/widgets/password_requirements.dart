import 'package:flutter/material.dart';

import '../utilities/password_policy.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.password,
    this.enabled = true,
  });

  final String password;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Requirement(
          label: 'At least ${PasswordPolicy.minimumLength} characters',
          isMet: PasswordPolicy.hasMinimumLength(password),
          enabled: enabled,
        ),
        const SizedBox(height: 4),
        _Requirement(
          label: 'Contains an uppercase letter',
          isMet: PasswordPolicy.hasUppercase(password),
          enabled: enabled,
        ),
        const SizedBox(height: 4),
        _Requirement(
          label: 'Contains a lowercase letter',
          isMet: PasswordPolicy.hasLowercase(password),
          enabled: enabled,
        ),
        const SizedBox(height: 4),
        _Requirement(
          label: 'Contains a number',
          isMet: PasswordPolicy.hasNumber(password),
          enabled: enabled,
        ),
        const SizedBox(height: 4),
        _Requirement(
          label: 'Contains a symbol',
          isMet: PasswordPolicy.hasSymbol(password),
          enabled: enabled,
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.label,
    required this.isMet,
    required this.enabled,
  });

  final String label;
  final bool isMet;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final metColor = const Color(0xFF2E7D32);
    final pendingColor = enabled
        ? const Color(0xFF64748B)
        : const Color(0xFF9CA3AF);
    final color = isMet && enabled ? metColor : pendingColor;

    return Row(
      children: [
        Icon(
          isMet && enabled ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: isMet && enabled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
