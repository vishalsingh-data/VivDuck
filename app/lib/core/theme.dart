import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VivDuck palette — warm duck yellow, beak orange, pond teal, ink navy.
class VD {
  static const yellow = Color(0xFFFFC93C);
  static const yellowSoft = Color(0xFFFFF1C7);
  static const orange = Color(0xFFFF8A3D);
  static const teal = Color(0xFF1FA5A0);
  static const tealSoft = Color(0xFFD7F2F0);
  static const ink = Color(0xFF1B2440);
  static const inkSoft = Color(0xFF5A6380);
  static const cream = Color(0xFFFFFBF2);
  static const line = Color(0xFFEFE6D2);

  static const solid = Color(0xFF22A06B);
  static const partial = Color(0xFFF2A516);
  static const missing = Color(0xFFE5484D);

  static const darkBg = Color(0xFF12172A);
  static const darkSurface = Color(0xFF1C2238);
  static const darkLine = Color(0xFF2B3352);

  static const radius = 20.0;
}

/// Theme-aware colours that change between light and dark.
extension VDColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? VD.darkBg : VD.cream;
  Color get surface => isDark ? VD.darkSurface : Colors.white;
  Color get line => isDark ? VD.darkLine : VD.line;
  Color get ink => isDark ? const Color(0xFFF2F4FA) : VD.ink;
  Color get inkSoft => isDark ? const Color(0xFFA3ABC6) : VD.inkSoft;
  TextTheme get text => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: VD.yellow,
    brightness: brightness,
    primary: dark ? VD.yellow : VD.ink,
    onPrimary: dark ? VD.ink : Colors.white,
    secondary: VD.orange,
    tertiary: VD.teal,
    surface: dark ? VD.darkSurface : Colors.white,
  );
  final ink = dark ? const Color(0xFFF2F4FA) : VD.ink;
  final base = GoogleFonts.nunitoTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: ink, displayColor: ink);
  final display = GoogleFonts.fredokaTextTheme(base);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? VD.darkBg : VD.cream,
    textTheme: base.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w600),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: dark ? VD.darkLine : VD.line, width: 1.5),
        foregroundColor: ink,
        textStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? VD.darkBg : VD.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? VD.darkLine : VD.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? VD.darkLine : VD.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VD.orange, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: VD.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

TextStyle monoStyle(BuildContext context, {double size = 13.5}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      height: 1.55,
      color: context.ink,
      // Show code exactly as typed: no `<=` → `≤` ligatures.
      fontFeatures: const [
        FontFeature.disable('calt'),
        FontFeature.disable('liga'),
      ],
    );
