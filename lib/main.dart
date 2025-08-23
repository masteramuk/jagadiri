import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:jagadiri/screens/home_screen.dart';
// No specific imports needed for individual setting screens
import 'package:jagadiri/providers/theme_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  final databaseService = DatabaseService();
  final savedThemeName = await databaseService.getSetting('themeName') ?? 'Light';

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (context) => databaseService,
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(savedThemeName),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'JagaDiri',
      theme: themeProvider.currentTheme,
      home: HomeScreen(),
      routes: {
        // No specific routes needed as settings are consolidated
      },
    );
  }
}
