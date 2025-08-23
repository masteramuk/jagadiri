import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/services/database_service.dart'; // Import DatabaseService
import 'package:jagadiri/screens/home_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Required for database initialization

  if (kIsWeb) {
    // Use FFI web factory in web apps
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(
    Provider<DatabaseService>(
      create: (context) => DatabaseService(), // Provide DatabaseService
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
      home: HomeScreen(),
    );
  }
}
