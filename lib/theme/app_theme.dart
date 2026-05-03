import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background   = Color(0xFFF7F9F6);
  static const card         = Color(0xFFFFFFFF);
  static const cardElevated = Color(0xFFEEF3EE);
  static const primary      = Color(0xFF5B8C6A);
  static const primaryFg    = Color(0xFFFFFFFF);
  static const secondary    = Color(0xFF7C9E8A);
  static const warning      = Color(0xFFD4862A);
  static const danger       = Color(0xFFD94F4F);
  static const success      = Color(0xFF4A8C6A);
  static const textPrimary  = Color(0xFF1A2E22);
  static const textMuted    = Color(0xFF7A9485);
  static const muted        = Color(0xFFE8F0E9);
  static const border       = Color(0xFFD4E2D8);
}

class AppRankColors {
  static const wanderer   = Color(0xFF7A9485);
  static const seeker     = Color(0xFF7C9E8A);
  static const apprentice = Color(0xFF5B8C6A);
  static const guardian   = Color(0xFF4A8C6A);
  static const sage       = Color(0xFFD4862A);
  static const mindMaster = Color(0xFFB8922A);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      surface: AppColors.card,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.danger,
      onPrimary: AppColors.primaryFg,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: AppColors.border,
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
        (s) => s.contains(MaterialState.selected)
            ? AppColors.primary
            : AppColors.textMuted,
      ),
      trackColor: MaterialStateProperty.resolveWith(
        (s) => s.contains(MaterialState.selected)
            ? AppColors.primary.withOpacity(0.3)
            : AppColors.muted,
      ),
    ),
  );
}