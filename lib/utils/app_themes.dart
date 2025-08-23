import 'package:flutter/material.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blueGrey,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blueGrey,
      foregroundColor: Colors.white,
    ),
  );

  // Add more themes here
  static final ThemeData oceanTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.cyan,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.cyan,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData greenTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData orangeTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.orange,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData grassTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.lightGreen,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.lightGreen,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData novelTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.purple,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.purple,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData funkyTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.pink,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.pink,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData highContrastTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.grey,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.yellow,
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.yellow,
      onPrimary: Colors.black,
      secondary: Colors.cyanAccent,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      background: Colors.black,
      onBackground: Colors.white,
      error: Colors.redAccent,
      onError: Colors.black,
    ),
  );

  static final ThemeData superPinkyTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.pink,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.pinkAccent,
      foregroundColor: Colors.white,
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.pinkAccent,
      onPrimary: Colors.white,
      secondary: Colors.purpleAccent,
      onSecondary: Colors.white,
      surface: Colors.pink,
      onSurface: Colors.white,
      background: Colors.pink.shade50,
      onBackground: Colors.pink.shade900,
      error: Colors.red,
      onError: Colors.white,
    ),
  );

  static Map<String, ThemeData> get themes => {
        'Light': lightTheme,
        'Dark': darkTheme,
        'Ocean': oceanTheme,
        'Green': greenTheme,
        'Orange': orangeTheme,
        'Grass': grassTheme,
        'Novel': novelTheme,
        'Funky': funkyTheme,
        'High Contrast': highContrastTheme,
        'Super Pinky': superPinkyTheme,
      };
}
