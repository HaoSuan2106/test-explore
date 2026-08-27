import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Small "STEP X OF 4" progress indicator used by every Recommend Place
/// wizard screen so the user always knows where they are in the flow.
class WizardStepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const WizardStepIndicator({
    super.key,
    required this.current,
    this.total = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 5,
              backgroundColor: AppColors.outlineVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'STEP $current OF $total',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
