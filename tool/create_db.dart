import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

Future<void> main() async {
  sqfliteFfiInit();

  var databaseFactory = databaseFactoryFfi;
  String path = 'assets/data/jagadiri.db';

  // Delete the database if it exists
  if (await File(path).exists()) {
    await File(path).delete();
  }

  Database db = await databaseFactory.openDatabase(path);

  await db.execute('''
CREATE TABLE sugar_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  mealTimeCategory TEXT,
  mealType TEXT,
  value REAL,
  status TEXT
)
      ''');

  await db.execute('''
CREATE TABLE bp_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  timeName TEXT,
  systolic INTEGER,
  diastolic INTEGER,
  pulseRate INTEGER,
  status TEXT
)
      ''');

  await db.close();

  print('Database created at $path');
}
