import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VivDuck palette. Neutral slate surfaces carry the interface; duck amber
/// is the brand accent and appears sparingly (logo, highlights, focus).
class VD {
  static const yellow = Color(0xFFF5B83D);
  static const yellowSoft = Color(0xFFFEF4DC);
  static const orange = Color(0xFFE8692C);
  static const teal = Color(0xFF0E8C86);
  static const tealSoft = Color(0xFFDDF3F1);
  static const ink = Color(0xFF111827);
  static const inkSoft = Color(0xFF5B6475);
  static const cream = Color(0xFFF7F8FA);
  static const line = Color(0xFFE3E6EC);

  static const solid = Color(0xFF15935F);
  static const partial = Color(0xFFD48A0B);
  static const missing = Color(0xFFD14343);

  static const darkBg = Color(0xFF0C111D);
  static const darkSurface = Color(0xFF141B2B);
  static const darkLine = Color(0xFF262F44);

  static const radius = 14.0;
}

/// Theme-aware colours that change between light and dark.
extension VDColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? VD.darkBg : VD.cream;
  Color get surface => isDark ? VD.darkSurface : Colors.white;
  Color get line => isDark ? VD.darkLine : VD.line;
  Color get ink => isDark ? const Color(0xFFEEF1F6) : VD.ink;
  Color get inkSoft => isDark ? const Color(0xFF9AA3B5) : VD.inkSoft;
  TextTheme get text => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFEEF1F6) : VD.ink;
  final inkSoft = dark ? const Color(0xFF9AA3B5) : VD.inkSoft;
  final line = dark ? VD.darkLine : VD.line;
  final surface = dark ? VD.darkSurface : Colors.white;
  final primary = dark ? VD.yellow : VD.ink;
  final onPrimary = dark ? VD.ink : Colors.white;

  final scheme = ColorScheme.fromSeed(
    seedColor: VD.yellow,
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: VD.orange,
    tertiary: VD.teal,
    surface: surface,
    outline: line,
    outlineVariant: line,
  );

  // One typeface throughout: Inter reads as calm and precise at every size.
  final base = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: ink, displayColor: ink);
  TextStyle? heading(TextStyle? s, {double spacing = -0.4}) =>
      s?.copyWith(fontWeight: FontWeight.w700, letterSpacing: spacing);

  final radius = BorderRadius.circular(10);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? VD.darkBg : VD.cream,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.copyWith(
      displayLarge: heading(base.displayLarge, spacing: -1.6),
      displayMedium: heading(base.displayMedium, spacing: -1.2),
      displaySmall: heading(base.displaySmall, spacing: -1.0),
      headlineLarge: heading(base.headlineLarge, spacing: -0.8),
      headlineMedium: heading(base.headlineMedium, spacing: -0.6),
      headlineSmall: heading(base.headlineSmall),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 0,
        animationDuration: const Duration(milliseconds: 150),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: radius),
        foregroundColor: ink,
        side: BorderSide(color: line),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: radius),
        foregroundColor: dark ? VD.yellow : VD.ink,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: inkSoft,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: line),
        selectedBackgroundColor: dark
            ? VD.yellow.withValues(alpha: 0.16)
            : VD.ink.withValues(alpha: 0.06),
        selectedForegroundColor: ink,
        foregroundColor: inkSoft,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: line),
      ),
      side: BorderSide(color: line),
      backgroundColor: surface,
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
        color: ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? VD.darkBg : Colors.white,
      hintStyle: TextStyle(color: inkSoft.withValues(alpha: 0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: dark ? VD.yellow : VD.ink, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: ink,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: line),
      ),
      elevation: 6,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A3348) : VD.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2A3348) : VD.ink,
      shape: RoundedRectangleBorder(borderRadius: radius),
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
