import 'package:flutter/material.dart';

class AppThemes {
  // Cache to avoid rebuilding themes multiple times
  static final Map<String, ThemeData> _themeCache = {};

  // Common card theme for all themes
  static CardThemeData _cardTheme(Color color) => CardThemeData(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: color,
  );

  // Common button theme
  static ElevatedButtonThemeData _elevatedButtonTheme(Color backgroundColor, {Color? foregroundColor}) {
    // Determine the best foreground color based on the background's brightness
    final Color effectiveForegroundColor = foregroundColor ??
        (ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
            ? Colors.white
            : Colors.black);

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: effectiveForegroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  // Common text theme based on text color
  static TextTheme _textTheme(Color primaryColor, {Color? secondaryColor}) {
    final Color bodyColor = secondaryColor ?? primaryColor;
    return TextTheme(
      headlineSmall: TextStyle(color: primaryColor),
      titleLarge: TextStyle(color: primaryColor),
      titleMedium: TextStyle(color: primaryColor),
      bodyLarge: TextStyle(color: bodyColor),
      bodyMedium: TextStyle(color: bodyColor),
    );
  }

  // Common bottom nav theme
  static BottomNavigationBarThemeData _bottomNavTheme({
    required Color backgroundColor,
    Color? selectedItemColor,
    Color? unselectedItemColor,
  }) {
    final bool isDarkBackground =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;

    // If a specific color isn't provided, calculate a smart one.
    final Color effectiveSelectedItemColor =
        selectedItemColor ?? (isDarkBackground ? Colors.white : Colors.black);
    final Color effectiveUnselectedItemColor =
        unselectedItemColor ?? (isDarkBackground ? Colors.white70 : Colors.black54);

    return BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: effectiveSelectedItemColor,
      unselectedItemColor: effectiveUnselectedItemColor,
      type: BottomNavigationBarType.fixed,
    );
  }

  // Common app bar theme
  static AppBarTheme _appBarTheme({
    required Color backgroundColor,
    required Color foregroundColor,
  }) =>
      AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 4,
      );

  // Base theme builder — removed `brightness` parameter (let colorScheme control it)
  static ThemeData _buildTheme({
    required MaterialColor primarySwatch,
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required AppBarTheme appBarTheme,
    required TextTheme textTheme,
    required CardThemeData cardTheme,
    required ElevatedButtonThemeData buttonTheme,
    required BottomNavigationBarThemeData bottomNavTheme,
  }) {
    return ThemeData(
      primarySwatch: primarySwatch,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: appBarTheme,
      textTheme: textTheme,
      cardTheme: cardTheme,
      bottomNavigationBarTheme: bottomNavTheme,
      elevatedButtonTheme: buttonTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      // Removed: brightness → now fully controlled by colorScheme
    );
  }

  // Lazy theme factory
  static ThemeData _getTheme(String name) {
    return _themeCache.putIfAbsent(name, () {
      switch (name) {
        case 'Light':
          return _buildTheme(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
                .copyWith(secondary: Colors.blueAccent),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.blueAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.blue),
          );

        case 'Dark':
          return _buildTheme(
            primarySwatch: Colors.blueGrey,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blueGrey,
              brightness: Brightness.dark,
            ).copyWith(secondary: Colors.cyanAccent),
            scaffoldBackgroundColor: Colors.grey.shade900,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.white, secondaryColor: Colors.white70),
            cardTheme: _cardTheme(Colors.grey.shade800),
            buttonTheme: _elevatedButtonTheme(Colors.blueGrey.shade600),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.blueGrey.shade900),
          );

        case 'Ocean':
          return _buildTheme(
            primarySwatch: Colors.cyan,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.cyan)
                .copyWith(secondary: Colors.tealAccent),
            scaffoldBackgroundColor: Colors.lightBlue.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.tealAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.cyan.shade800),
          );

        case 'Green':
          return _buildTheme(
            primarySwatch: Colors.green,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
                .copyWith(secondary: Colors.lightGreenAccent),
            scaffoldBackgroundColor: Colors.green.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.lightGreenAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.green.shade800),
          );

        case 'Orange':
          return _buildTheme(
            primarySwatch: Colors.orange,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange)
                .copyWith(secondary: Colors.deepOrangeAccent),
            scaffoldBackgroundColor: Colors.orange.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.deepOrangeAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.orange.shade800),
          );

        case 'Grass':
          return _buildTheme(
            primarySwatch: Colors.lightGreen,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightGreen)
                .copyWith(secondary: Colors.limeAccent),
            scaffoldBackgroundColor: Colors.lime.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.limeAccent),
            bottomNavTheme: _bottomNavTheme(
              backgroundColor: Colors.lightGreen.shade800,
              selectedItemColor: Colors.black, // Keep explicit override for design
            ),
          );

        case 'Novel':
          return _buildTheme(
            primarySwatch: Colors.purple,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.purple)
                .copyWith(secondary: Colors.deepPurpleAccent),
            scaffoldBackgroundColor: Colors.purple.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.deepPurpleAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.purple.shade800),
          );

        case 'Funky':
          return _buildTheme(
            primarySwatch: Colors.pink,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.pink)
                .copyWith(secondary: Colors.pinkAccent),
            scaffoldBackgroundColor: Colors.pink.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.black87),
            cardTheme: _cardTheme(Colors.white),
            buttonTheme: _elevatedButtonTheme(Colors.pinkAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.pink.shade800),
          );

        case 'High Contrast':
          return _buildTheme(
            primarySwatch: Colors.grey,
            colorScheme: ColorScheme.dark(
              primary: Colors.yellow,
              onPrimary: Colors.black,
              secondary: Colors.cyanAccent,
              onSecondary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
              error: Colors.redAccent,
              onError: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.yellow,
            ),
            textTheme: _textTheme(Colors.yellow, secondaryColor: Colors.white),
            cardTheme: _cardTheme(Colors.grey.shade900),
            buttonTheme: _elevatedButtonTheme(Colors.yellow),
            bottomNavTheme: _bottomNavTheme(
              backgroundColor: Colors.black,
              selectedItemColor: Colors.yellow,
              unselectedItemColor: Colors.white,
            ),
          );

        case 'Super Pinky':
          return _buildTheme(
            primarySwatch: Colors.pink,
            colorScheme: ColorScheme.light(
              primary: Colors.pinkAccent,
              onPrimary: Colors.white,
              secondary: Colors.purpleAccent,
              onSecondary: Colors.white,
              surface: Colors.pink,
              onSurface: Colors.white,
              error: Colors.red,
              onError: Colors.white,
            ),
            scaffoldBackgroundColor: Colors.pink.shade50,
            appBarTheme: _appBarTheme(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            textTheme: _textTheme(Colors.pink.shade900, secondaryColor: Colors.pink.shade800),
            cardTheme: _cardTheme(Colors.pink.shade100),
            buttonTheme: _elevatedButtonTheme(Colors.purpleAccent),
            bottomNavTheme: _bottomNavTheme(backgroundColor: Colors.pink.shade800),
          );

        default:
          return _getTheme('Light'); // fallback
      }
    });
  }

  /// Public getter: returns a map of lazy-loaded themes
  static Map<String, ThemeData> get themes => {
    for (final name in _themeNames) name: _getTheme(name),
  };

  // List of all theme names (used in for-loop above)
  static final List<String> _themeNames = [
    'Light',
    'Dark',
    'Ocean',
    'Green',
    'Orange',
    'Grass',
    'Novel',
    'Funky',
    'High Contrast',
    'Super Pinky',
  ];
}