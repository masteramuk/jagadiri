import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/services/google_sheets_service.dart';
import 'package:jagadiri/screens/profile_settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GoogleSheetsService()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JagaDiri',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ProfileSettingsScreen(),
    );
  }
}
