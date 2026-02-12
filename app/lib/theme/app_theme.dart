/// Mira Design System / App Theme
/// Ref: PLAN.md Section 3.3 (UX/Design Decisions), Section 0.8 (Production Quality)
///
/// Colors: Forest Green, Warm Earth, Warm White, Gold accent
/// Font: Inter (via google_fonts)
/// Spacing scale: 4, 8, 12, 16, 24, 32, 48dp
/// Touch targets: min 48x48dp
/// Line height: 1.5x body, 1.4x chat
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mira color palette
/// Ref: PLAN.md Section 3.3
class MiraColors {
  MiraColors._();

  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color warmEarth = Color(0xFFA68B6B);
  static const Color warmWhite = Color(0xFFF8F6F3);
  static const Color gold = Color(0xFFD4A574);
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF636366);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color divider = Color(0xFFE5E5EA);
  static const Color error = Color(0xFFD32F2F);
  static const Color surface = Colors.white;

  // Coach-specific colors
  static const Color coachMira = forestGreen;
  static const Color coachAtlas = Color(0xFF1E3A5F);
  static const Color coachLyra = Color(0xFF6B3FA0);
  static const Color coachSol = Color(0xFF1A7A7A);
  static const Color coachEmber = Color(0xFFC75B7A);
}

/// Spacing scale
/// Ref: PLAN.md Section 0.8 (Typography & Spacing)
class MiraSpacing {
  MiraSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double pagePadding = 16;
  static const double formPadding = 24;
}

/// Border radius scale
class MiraRadius {
  MiraRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 100;
}

/// App theme builder
class MiraTheme {
  MiraTheme._();

  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      // Headings
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: MiraColors.textPrimary,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: MiraColors.textPrimary,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: MiraColors.textPrimary,
        height: 1.3,
      ),
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: MiraColors.textPrimary,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: MiraColors.textPrimary,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MiraColors.textPrimary,
        height: 1.4,
      ),
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: MiraColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: MiraColors.textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: MiraColors.textSecondary,
        height: 1.5,
      ),
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: MiraColors.textPrimary,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: MiraColors.textSecondary,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: MiraColors.textTertiary,
        height: 1.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MiraColors.warmWhite,
      textTheme: textTheme,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: MiraColors.forestGreen,
        secondary: MiraColors.warmEarth,
        tertiary: MiraColors.gold,
        surface: MiraColors.surface,
        error: MiraColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: MiraColors.textPrimary,
        onError: Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: MiraColors.warmWhite,
        foregroundColor: MiraColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: MiraColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MiraColors.surface,
        selectedItemColor: MiraColors.forestGreen,
        unselectedItemColor: MiraColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiraColors.forestGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MiraRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiraColors.forestGreen,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MiraRadius.md),
          ),
          side: const BorderSide(color: MiraColors.forestGreen),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiraColors.forestGreen,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiraColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MiraRadius.md),
          borderSide: const BorderSide(color: MiraColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MiraRadius.md),
          borderSide: const BorderSide(color: MiraColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MiraRadius.md),
          borderSide: const BorderSide(color: MiraColors.forestGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MiraRadius.md),
          borderSide: const BorderSide(color: MiraColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MiraSpacing.base,
          vertical: MiraSpacing.md,
        ),
        hintStyle: GoogleFonts.inter(
          color: MiraColors.textTertiary,
          fontSize: 14,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: MiraColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MiraRadius.lg),
          side: const BorderSide(color: MiraColors.divider, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MiraColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MiraRadius.xl),
          ),
        ),
        showDragHandle: true,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: MiraColors.divider,
        thickness: 0.5,
        space: 0,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MiraRadius.sm),
        ),
      ),
    );
  }
}
