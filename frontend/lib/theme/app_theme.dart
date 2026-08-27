// import 'package:flutter/material.dart';

// import 'app_colors.dart';
// import 'app_spacing.dart';
// import 'app_typography.dart';

// /// AppTheme builds the comprehensive ThemeData using the Vibrant Getaway tokens
// class AppTheme {
//   AppTheme._();

//   static ThemeData get lightTheme {
//     return ThemeData(
//       useMaterial3: true,
//       scaffoldBackgroundColor: AppColors.background,
//       colorScheme: const ColorScheme.light(
//         primary: AppColors.primaryContainer, // Vibrant Coral (#FF7043)
//         onPrimary: AppColors.onPrimary,
//         primaryContainer: AppColors.primaryContainer,
//         onPrimaryContainer: AppColors.onPrimaryContainer,
//         secondary: AppColors.secondaryDark,
//         onSecondary: AppColors.onSecondary,
//         secondaryContainer: AppColors.secondaryContainer,
//         onSecondaryContainer: AppColors.onSecondaryContainer,
//         surface: AppColors.surfaceContainerLowest,
//         onSurface: AppColors.onSurface,
//         onSurfaceVariant: AppColors.onSurfaceVariant,
//         surfaceContainerLow: AppColors.surfaceContainerLow,
//         surfaceContainer: AppColors.surfaceContainer,
//         surfaceContainerHigh: AppColors.surfaceContainerHigh,
//         error: AppColors.error,
//         onError: AppColors.onError,
//         errorContainer: AppColors.errorContainer,
//         onErrorContainer: AppColors.onErrorContainer,
//         outline: AppColors.outline,
//         outlineVariant: AppColors.outlineVariant,
//       ),
//       fontFamily: AppTypography.fontFamily,
//       textTheme: TextTheme(
//         displayLarge: AppTypography.headlineXl,
//         displayMedium: AppTypography.headlineXlMobile,
//         headlineLarge: AppTypography.headlineLg,
//         headlineMedium: AppTypography.headlineMd,
//         bodyLarge: AppTypography.bodyLg,
//         bodyMedium: AppTypography.bodyMd,
//         labelLarge: AppTypography.labelLg,
//         labelSmall: AppTypography.labelSm,
//       ),
//       appBarTheme: AppBarTheme(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         centerTitle: true,
//         scrolledUnderElevation: 0,
//         titleTextStyle: AppTypography.headlineMd.copyWith(color: AppColors.secondaryDark),
//         iconTheme: const IconThemeData(color: AppColors.secondaryDark),
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primaryContainer,
//           foregroundColor: AppColors.onPrimary,
//           elevation: 0,
//           textStyle: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//           shape: const RoundedRectangleBorder(
//             borderRadius: AppSpacing.borderXl, // Pill shape (24px)
//           ),
//         ),
//       ),
//       outlinedButtonTheme: OutlinedButtonThemeData(
//         style: OutlinedButton.styleFrom(
//           foregroundColor: AppColors.primaryContainer,
//           side: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
//           textStyle: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w600),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//           shape: const RoundedRectangleBorder(
//             borderRadius: AppSpacing.borderXl, // Pill shape (24px)
//           ),
//         ),
//       ),
//       textButtonTheme: TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: AppColors.secondaryDark,
//           textStyle: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w600),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         ),
//       ),
//       cardTheme: const CardThemeData(
//         color: AppColors.surfaceContainerLowest,
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: AppSpacing.borderLg, // 16px
//           side: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
//         ),
//         margin: EdgeInsets.only(bottom: AppSpacing.stackMd),
//       ),
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.surfaceContainerLow, // #F4F3F3
//         hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.neutralDisabled),
//         labelStyle: AppTypography.labelLg.copyWith(color: AppColors.onSurfaceVariant),
//         contentPadding: AppSpacing.inputPadding,
//         border: OutlineInputBorder(
//           borderRadius: AppSpacing.borderMd, // 12px
//           borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: AppSpacing.borderMd, // 12px
//           borderSide: const BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: AppSpacing.borderMd, // 12px
//           borderSide: const BorderSide(color: AppColors.primaryContainer, width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: AppSpacing.borderMd, // 12px
//           borderSide: const BorderSide(color: AppColors.error, width: 1),
//         ),
//       ),
//       dialogTheme: DialogThemeData(
//         backgroundColor: AppColors.surfaceContainerLowest,
//         elevation: 4,
//         shape: const RoundedRectangleBorder(
//           borderRadius: AppSpacing.borderXl, // 24px
//         ),
//         titleTextStyle: AppTypography.headlineMd.copyWith(color: AppColors.secondaryDark, fontWeight: FontWeight.w700),
//         contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
//       ),
//       bottomNavigationBarTheme: BottomNavigationBarThemeData(
//         backgroundColor: AppColors.surfaceContainerLowest,
//         selectedItemColor: AppColors.primaryContainer,
//         unselectedItemColor: AppColors.neutralDisabled,
//         selectedLabelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
//         unselectedLabelStyle: AppTypography.labelSm,
//         type: BottomNavigationBarType.fixed,
//         elevation: 8,
//       ),
//     );
//   }
// }



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
abstract class AppTypography {
  static TextStyle get headlineXl => GoogleFonts.plusJakartaSans(
        fontSize: 32.0,
        fontWeight: FontWeight.w700,
        height: 40.0 / 32.0,
        letterSpacing: -0.64, // -0.02em
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineXlMobile => GoogleFonts.plusJakartaSans(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        height: 36.0 / 28.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLg => GoogleFonts.plusJakartaSans(
        fontSize: 24.0,
        fontWeight: FontWeight.w700,
        height: 32.0 / 24.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMd => GoogleFonts.plusJakartaSans(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        height: 28.0 / 20.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        height: 24.0 / 16.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 20.0 / 14.0,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        height: 20.0 / 14.0,
        letterSpacing: 0.14,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        height: 16.0 / 12.0,
        color: AppColors.textMuted,
      );
}

/// Complete AppTheme definition
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.textSecondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.headlineXl,
        displayMedium: AppTypography.headlineLg,
        titleLarge: AppTypography.headlineMd,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        labelLarge: AppTypography.labelLg,
        labelSmall: AppTypography.labelSm,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
