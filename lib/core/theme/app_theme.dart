import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.warmWhite,
        onPrimary: AppColors.black,
        secondary: AppColors.steelBlue,
        onSecondary: AppColors.warmWhite,
        tertiary: AppColors.amber,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.warmWhite,
        onSurfaceVariant: AppColors.textMuted,
        outline: AppColors.outline,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 42,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: AppColors.warmWhite,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.warmWhite,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppColors.warmWhite,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textMuted,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textMuted,
        ),
        labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.warmWhite,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.warmWhite,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.steelBlue),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.warmWhite,
          foregroundColor: AppColors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.warmWhite,
          side: BorderSide(color: AppColors.warmWhite.withValues(alpha: 0.22)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.warmWhite,
        inactiveTrackColor: AppColors.warmWhite.withValues(alpha: 0.22),
        thumbColor: AppColors.amber,
        overlayColor: AppColors.amber.withValues(alpha: 0.14),
      ),
    );
  }
}
