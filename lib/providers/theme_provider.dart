// providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:jagadiri/utils/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  late String _themeName;
  late ThemeData _currentTheme;

  ThemeProvider(String themeName) {
    _themeName = themeName;
    _currentTheme = AppThemes.themes[themeName] ??
        AppThemes.themes['Light'] ??
        ThemeData.light(); // Ultimate fallback
  }

  ThemeData get currentTheme => _currentTheme;
  String get themeName => _themeName;

  void setTheme(String name) {
    if (AppThemes.themes.containsKey(name)) {
      _themeName = name;
      _currentTheme = AppThemes.themes[name]!;
      notifyListeners();
    }
  }
}