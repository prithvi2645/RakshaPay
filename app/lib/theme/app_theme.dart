import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette and typography from the RakshaPay design.
///
/// Every colour the UI uses should come from here — the design leans on a
/// small navy/blue set plus three semantic risk colours, and scattering raw
/// hex around the widgets is how that drifts.
class AppColors {
  // Brand
  static const navy = Color(0xFF0D1B3E);
  static const primary = Color(0xFF1565C0);
  static const primaryDark = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFF1976D2);

  // Neutrals
  static const muted = Color(0xFF5C6891);
  static const background = Color(0xFFF5F7FF);
  static const surfaceTint = Color(0xFFEEF2FF);
  static const blueTint = Color(0xFFE3EFFF);

  // Safe
  static const safe = Color(0xFF2E7D32);
  static const safeBg = Color(0xFFE8F5E9);
  static const safeBorder = Color(0xFFA5D6A7);
  static const safeAccent = Color(0xFF4CAF50);

  // Caution
  static const caution = Color(0xFFE65100);
  static const cautionBg = Color(0xFFFFF3E0);
  static const cautionBorder = Color(0xFFFFB74D);
  static const cautionDeep = Color(0xFFBF360C);

  // High risk
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFFEBEE);
  static const dangerBorder = Color(0xFFFFCDD2);
  static const dangerDeep = Color(0xFFB71C1C);
  static const dangerAccent = Color(0xFFFF5252);

  static const star = Color(0xFFF57F17);
}

class AppTheme {
  /// Display face — the design uses Nunito's heaviest weight for headings.
  static TextStyle heading(
    double size, {
    Color color = AppColors.navy,
    FontWeight weight = FontWeight.w900,
    double? height,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Body face.
  static TextStyle body(
    double size, {
    Color color = AppColors.navy,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) =>
      GoogleFonts.nunitoSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.nunitoSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.navy,
        displayColor: AppColors.navy,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTheme.heading(20, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.surfaceTint, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceTint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceTint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}

/// Soft card shadow used throughout the design.
const kCardShadow = [
  BoxShadow(
    color: Color(0x0F0D1B3E),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];
