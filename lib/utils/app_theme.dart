import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds — Dark Premium
  static const bg = Color(0xFF090C14);
  static const surface = Color(0xFF161B2C);
  static const surfaceSecondary = Color(0xFF1E2436);
  static const card = Color(0xFF161B2C);
  static const cardBorder = Color(0xFF252B40);

  // Brand
  static const primary = Color(0xFF7C4DFF);
  static const secondary = Color(0xFFFF9F1C);
  static const accent = Color(0xFF7C4DFF);
  static const accentAlt = Color(0xFFFF9F1C);
  static const gold = Color(0xFFFF9F1C);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const cyan = Color(0xFF32ADE6);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF); // white @ 70%
  static const textTertiary = Color(0x80FFFFFF); // white @ 50%

  // Dark mode (kept for compatibility — same as bg/surface now)
  static const darkBg = Color(0xFF090C14);
  static const darkSurface = Color(0xFF161B2C);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // Kept for backwards compatibility with any code still calling AppTheme.light
  static ThemeData get light => dark;
}
