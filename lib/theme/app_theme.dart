import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgTop = Color(0xFFFFF3E0);
  static const Color bgBottom = Color(0xFFE3F2FD);
  static const Color bgTopDark = Color(0xFF0F172A);
  static const Color bgBottomDark = Color(0xFF111827);
  static const Color ink = Color(0xFF1D1B20);
  static const Color mutedInk = Color(0xFF5F5B66);
  static const Color primary = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF00897B);
  static const Color accent = Color(0xFFFF6F00);

  static ThemeData light() {
    final textTheme = _textTheme(isDark: false);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Colors.white,
      onSurface: ink,
    );

    return _baseTheme(scheme, textTheme, isDark: false);
  }

  static ThemeData dark() {
    final textTheme = _textTheme(isDark: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF82B1FF),
      secondary: const Color(0xFF64FFDA),
      tertiary: const Color(0xFFFFB74D),
      surface: const Color(0xFF111827),
      onSurface: const Color(0xFFE5E7EB),
    );

    return _baseTheme(scheme, textTheme, isDark: true);
  }

  static TextTheme _textTheme({required bool isDark}) {
    final textColor = isDark ? const Color(0xFFE5E7EB) : ink;
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : mutedInk;

    return GoogleFonts.manropeTextTheme().copyWith(
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        height: 1.35,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        height: 1.3,
        color: mutedColor,
      ),
      bodySmall: GoogleFonts.manrope(fontSize: 12, color: mutedColor),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ThemeData _baseTheme(
    ColorScheme scheme,
    TextTheme textTheme, {
    required bool isDark,
  }) {
    final inputFill = isDark
        ? const Color(0xFF1F2937).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF111827).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: textTheme.bodyMedium,
        prefixIconColor: scheme.primary,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: isDark ? Colors.black : Colors.white,
          backgroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF0B1220) : ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        selectedColor: scheme.secondary.withValues(alpha: 0.18),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        side: BorderSide(color: borderColor),
        labelStyle: textTheme.bodyMedium ?? const TextStyle(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF111827).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.9),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),
    );
  }
}
