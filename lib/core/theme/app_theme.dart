import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colours
  static const Color primary       = Color(0xFF6C5CE7);
  static const Color primaryLight  = Color(0xFF8B7FF5);
  static const Color primaryDark   = Color(0xFF4834D4);
  static const Color accent        = Color(0xFF00CEC9);
  static const Color danger        = Color(0xFFE17055);
  static const Color warning       = Color(0xFFFDCB6E);
  static const Color success       = Color(0xFF00B894);
  static const Color batteryLow    = Color(0xFFE17055);
  static const Color batteryMed    = Color(0xFFFDCB6E);
  static const Color batteryHigh   = Color(0xFF00B894);

  // Dark surfaces
  static const Color surfaceDark   = Color(0xFF1A1A2E);
  static const Color cardDark      = Color(0xFF16213E);
  static const Color navDark       = Color(0xFF0F3460);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.dark(
      primary:   primary,
      secondary: accent,
      surface:   surfaceDark,
      error:     danger,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: surfaceDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D2D4E), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF8888AA)),
      labelStyle: const TextStyle(color: Color(0xFF8888AA)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardDark,
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2D2D4E), thickness: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? primary : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? primary.withOpacity(0.4) : const Color(0xFF2D2D4E)),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      headlineSmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      bodyLarge:      TextStyle(fontSize: 16, color: Colors.white),
      bodyMedium:     TextStyle(fontSize: 14, color: Color(0xFFCCCCEE)),
      bodySmall:      TextStyle(fontSize: 12, color: Color(0xFF8888AA)),
      labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
    ),
  );
}
