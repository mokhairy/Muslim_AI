import 'package:flutter/material.dart';

ThemeData buildMuslimAiTheme() {
  const ink = Color(0xFF15211A);
  const evergreen = Color(0xFF234233);
  const cedar = Color(0xFF58735F);
  const sand = Color(0xFFF2E8D2);
  const mist = Color(0xFFF7F3E8);
  const accent = Color(0xFFC89545);

  final scheme = ColorScheme.fromSeed(
    seedColor: evergreen,
    brightness: Brightness.light,
    primary: evergreen,
    secondary: accent,
    surface: mist,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: mist,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: ink,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.05,
      ),
      headlineSmall: TextStyle(
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: evergreen,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: cedar, fontSize: 14, height: 1.45),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      indicatorColor: sand,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: cedar.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: accent),
      ),
    ),
  );
}
