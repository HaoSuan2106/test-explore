
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System Color Tokens (Vibrant Getaway)
abstract class AppColors {
  // Brand & Accent
  static const Color primary = Color(0xFFFF7043); // Primary Coral
  static const Color primaryDark = Color(0xFFAC3509);
  static const Color primaryContainer = Color(0xFFFFDBD0);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF641800);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAF9F9);
  static const Color surfaceCard = Color(0xFFF4F5F7);
  static const Color surfaceDim = Color(0xFFDADADA);
  static const Color surfaceVariant = Color(0xFFE9E8E8);

  // Typography & Content
  static const Color textPrimary = Color(0xFF2D3142); // Secondary token
  static const Color textSecondary = Color(0xFF5A5D70);
  static const Color textMuted = Color(0xFF9E9E9E);

  // Outlines & Borders
  static const Color outline = Color(0xFFE0E0E0);
  static const Color outlineVariant = Color(0xFFE0BFB6);

  // Semantic Statuses
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
}

/// Spacing System (8px base grid)
abstract class AppSpacing {
  static const double containerMargin = 20.0;
  static const double gutterMd = 16.0;
  static const double stackSm = 8.0;
  static const double stackMd = 16.0;
  static const double stackLg = 24.0;
  static const double sectionGap = 32.0;
}

/// Corner Radii Tokens
abstract class AppRadii {
  static const double sm = 4.0;
  static const double defaultRadius = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedDefault = BorderRadius.all(Radius.circular(defaultRadius));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(full));
}

/// Elevation & Shadow Tokens
abstract class AppShadows {
  static const List<BoxShadow> softElevation = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      blurRadius: 20.0,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> navElevation = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 16.0,
      offset: Offset(0, -4),
    ),
  ];
}

/// Typography Hierarchy (Plus Jakarta Sans)
///
/// Styles are built ONCE as cached `static final` fields instead of being
/// re-created on every access. Previously each `AppTypography.bodyMd` call
/// invoked `GoogleFonts.plusJakartaSans(...)` and allocated a fresh
/// [TextStyle] (plus font-resolution bookkeeping) â€” that churn happened on
/// every PostCard build (several styles Ã— many cards Ã— rebuilds). The cached
/// styles are immutable and byte-for-byte identical in appearance; callers
/// that need tweaks still use `.copyWith(...)`, which only allocates the
/// small delta instead of the whole style.
abstract class AppTypography {
  static final TextStyle headlineXl = GoogleFonts.plusJakartaSans(
        fontSize: 32.0,
        fontWeight: FontWeight.w700,
        height: 40.0 / 32.0,
        letterSpacing: -0.64, // -0.02em
        color: AppColors.textPrimary,
      );

  static final TextStyle headlineXlMobile = GoogleFonts.plusJakartaSans(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        height: 36.0 / 28.0,
        color: AppColors.textPrimary,
      );

  static final TextStyle headlineLg = GoogleFonts.plusJakartaSans(
        fontSize: 24.0,
        fontWeight: FontWeight.w700,
        height: 32.0 / 24.0,
        color: AppColors.textPrimary,
      );

  static final TextStyle headlineMd = GoogleFonts.plusJakartaSans(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        height: 28.0 / 20.0,
        color: AppColors.textPrimary,
      );

  static final TextStyle bodyLg = GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        height: 24.0 / 16.0,
        color: AppColors.textPrimary,
      );

  static final TextStyle bodyMd = GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 20.0 / 14.0,
        color: AppColors.textSecondary,
      );

  static final TextStyle labelLg = GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        height: 20.0 / 14.0,
        letterSpacing: 0.14,
        color: AppColors.textPrimary,
      );

  static final TextStyle labelSm = GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        height: 16.0 / 12.0,
        color: AppColors.textMuted,
      );
}