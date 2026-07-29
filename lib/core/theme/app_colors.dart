import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // 基本ブランドカラー
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color tertiary = Color(0xFF8B5CF6);

  // 状態カラー
  static const Color success = Color(0xFF168447);
  static const Color warning = Color(0xFFB76E00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF2563EB);

  // ライトテーマ
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF3F5F9);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ダークテーマ
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF171A22);
  static const Color darkSurfaceVariant = Color(0xFF20242E);
  static const Color darkTextPrimary = Color(0xFFF4F6FA);
  static const Color darkTextSecondary = Color(0xFFAEB6C5);
  static const Color darkBorder = Color(0xFF343A48);

  // 旧コード互換
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color border = lightBorder;

  // カテゴリカラー
  static const Color attractionForeground = Color(0xFF2457A6);
  static const Color attractionBackground = Color(0xFFEAF2FF);
  static const Color attractionBorder = Color(0xFFA9C5F2);

  static const Color restaurantForeground = Color(0xFF287A4B);
  static const Color restaurantBackground = Color(0xFFE8F5ED);
  static const Color restaurantBorder = Color(0xFFA5D6B8);

  static const Color showForeground = Color(0xFF6A3DA1);
  static const Color showBackground = Color(0xFFF2EAFE);
  static const Color showBorder = Color(0xFFC9AFE8);

  static const Color paradeForeground = Color(0xFF9A4C00);
  static const Color paradeBackground = Color(0xFFFFF0E0);
  static const Color paradeBorder = Color(0xFFFFC27F);

  static const Color greetingForeground = Color(0xFF9A3F70);
  static const Color greetingBackground = Color(0xFFFDEAF4);
  static const Color greetingBorder = Color(0xFFE8AFCB);

  static const Color shopForeground = Color(0xFF7A5B16);
  static const Color shopBackground = Color(0xFFFFF8DF);
  static const Color shopBorder = Color(0xFFE6CE81);

  static const Color serviceForeground = Color(0xFF4D6470);
  static const Color serviceBackground = Color(0xFFEDF3F5);
  static const Color serviceBorder = Color(0xFFB7C8CF);

  static ColorScheme get lightColorScheme {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
      surface: lightSurface,
    ).copyWith(
      surfaceContainerLowest: lightSurface,
      surfaceContainerLow: lightSurfaceVariant,
      surfaceContainer: const Color(0xFFEEF1F6),
      surfaceContainerHigh: const Color(0xFFE8ECF2),
      outline: const Color(0xFF98A2B3),
      outlineVariant: lightBorder,
    );
  }

  static ColorScheme get darkColorScheme {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFFB5B2FF),
      secondary: const Color(0xFF8CD4FF),
      tertiary: const Color(0xFFD0BCFF),
      error: const Color(0xFFFFB4AB),
      surface: darkSurface,
    ).copyWith(
      surfaceContainerLowest: darkSurface,
      surfaceContainerLow: darkSurfaceVariant,
      surfaceContainer: const Color(0xFF252A35),
      surfaceContainerHigh: const Color(0xFF2D3340),
      outline: const Color(0xFF8E96A6),
      outlineVariant: darkBorder,
    );
  }
}