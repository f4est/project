import 'package:flutter/material.dart';

ThemeData buildAppTheme({double fontScale = 1.0}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    secondary: const Color(0xFFF59E0B),
    surface: const Color(0xFFF8FAF8),
    brightness: Brightness.light,
  );
  final scaledTextTheme = const TextTheme(
    displayLarge: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1E1F1F),
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1E1F1F),
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1E1F1F),
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1E1F1F),
    ),
    titleLarge: TextStyle(fontSize: 14, color: Color(0xFF2D2E2E)),
    titleMedium: TextStyle(fontSize: 14, color: Color(0xFF2D2E2E)),
    bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2D2E2E)),
  ).apply(fontSizeFactor: fontScale);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3F6F5),
    textTheme: scaledTextTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: const Color(0xFFDDF0ED),
      foregroundColor: const Color(0xFF1E1F1F),
      titleTextStyle: TextStyle(
        color: Color(0xFF1E1F1F),
        fontSize: 20 * fontScale,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: Color(0xFFF4F8F7),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFF2F6F5),
      indicatorColor: const Color(0xFFC9ECE6),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 18 * fontScale, color: const Color(0xFF2D2E2E)),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 32,
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF042E2B)
              : const Color(0xFF485152),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.primaryContainer,
      contentTextStyle: TextStyle(color: scheme.onPrimaryContainer),
    ),
  );
}
