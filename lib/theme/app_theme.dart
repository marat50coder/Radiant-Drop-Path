import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentCyan,
        secondary: AppColors.accentGold,
        surface: AppColors.panel,
        error: AppColors.danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentCyan,
          foregroundColor: const Color(0xFF041017),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.accentCyan,
        thumbColor: AppColors.accentGold,
        inactiveTrackColor: AppColors.gridLine,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Reusable neon-tech text style helper.
TextStyle titleGlow({double size = 28, Color color = AppColors.accentCyan}) {
  return TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 1.1,
    shadows: [
      Shadow(color: color.withValues(alpha: 0.85), blurRadius: 18),
      Shadow(color: color.withValues(alpha: 0.55), blurRadius: 36),
    ],
  );
}
