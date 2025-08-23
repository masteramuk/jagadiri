import 'package:flutter/material.dart';
import 'package:jagadiri/utils/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme;
  String _currentThemeName;

  ThemeProvider(String initialThemeName)
      : _currentThemeName = initialThemeName,
        _currentTheme = AppThemes.themes[initialThemeName] ?? AppThemes.lightTheme;

  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  void setTheme(String themeName) {
    _currentTheme = AppThemes.themes[themeName] ?? AppThemes.lightTheme;
    _currentThemeName = themeName;
    notifyListeners();
  }
}
