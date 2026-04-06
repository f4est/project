import 'package:flutter/material.dart';

ThemeData buildAppTheme({double fontScale = 1.0}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    secondary: const Color(0xFF546E7A),
    surface: const Color(0xFFFFFFFF),
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
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    textTheme: scaledTextTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E1F1F),
      titleTextStyle: TextStyle(
        color: Color(0xFF1E1F1F),
        fontSize: 19 * fontScale,
        fontWeight: FontWeight.w600,
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
      color: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE8EFF7),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 14 * fontScale, color: const Color(0xFF2D2E2E)),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF1C4E80)
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

ThemeData buildDarkAppTheme({double fontScale = 1.0}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF90CAF9),
    brightness: Brightness.dark,
  );
  final scaledTextTheme = const TextTheme(
    displayLarge: TextStyle(fontSize: 42, fontWeight: FontWeight.w600),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 14),
    titleMedium: TextStyle(fontSize: 14),
    bodyLarge: TextStyle(fontSize: 16),
  ).apply(fontSizeFactor: fontScale);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0F1217),
    textTheme: scaledTextTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: const Color(0xFF151A22),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19 * fontScale,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: const Color(0xFF1A202A),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF151A22),
      indicatorColor: const Color(0xFF263242),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 14 * fontScale, color: Colors.white70),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF90CAF9)
              : Colors.white54,
        ),
      ),
    ),
  );
}
