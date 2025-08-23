import 'package:flutter/services.dart';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' show dirname;
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:flutter/foundation.dart'; // For debugPrint

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Use the FFI web factory
      final factory = databaseFactoryFfiWeb;
      final dbPath = 'jagadiri.db';
      final db = await factory.openDatabase(dbPath);
      await _onCreate(db, 2);
      return db;
    } else {
      String databasesPath = await getDatabasesPath();
      String dbPath = join(databasesPath, 'jagadiri.db');

      // Check if the database exists
      var exists = await databaseExists(dbPath);

      if (!exists) {
        // Should happen only the first time you launch your application
        debugPrint("Creating new copy from asset");

        // Make sure the parent directory exists
        try {
          await Directory(dirname(dbPath)).create(recursive: true);
        } catch (_) {}

        // Copy from asset
        ByteData data = await rootBundle.load(join("assets", "data", "jagadiri.db"));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(dbPath).writeAsBytes(bytes, flush: true);

        return await openDatabase(dbPath);
      } else {
        return await openDatabase(
          dbPath,
          version: 2,
          onUpgrade: _onUpgrade,
        );
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database tables...');
    await db.execute(
      '''
CREATE TABLE sugar_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  mealTimeCategory TEXT,
  mealType TEXT,
  value REAL,
  status TEXT
)
      '''
    );
    debugPrint('sugar_records table created.');

    await db.execute(
      '''
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
      '''
    );
    debugPrint('bp_records table created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version \$oldVersion to \$newVersion');
    if (oldVersion < 2) {
      // Drop the old sugar_records table and create the new one
      await db.execute('DROP TABLE IF EXISTS sugar_records');
      debugPrint('Old sugar_records table dropped.');
      await db.execute(
        '''
CREATE TABLE sugar_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  mealTimeCategory TEXT,
  mealType TEXT,
  value REAL,
  status TEXT
)
        '''
      );
      debugPrint('New sugar_records table created during upgrade.');
    }
    // Add other migration steps for future versions here
  }

  // Sugar Record Operations
  Future<int> insertSugarRecord(SugarRecord record) async {
    final db = await database;
    final map = record.toDbMap();
    debugPrint('Inserting sugar record: \$map');
    try {
      final id = await db.insert('sugar_records', map);
      debugPrint('Sugar record inserted with id: \$id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting sugar record: $e\n$s');
      rethrow; // Re-throw the error to be caught by the UI
    }
  }

  Future<List<SugarRecord>> getSugarRecords() async {
    final db = await database;
    debugPrint('Querying sugar records...');
    try {
      final List<Map<String, dynamic>> maps = await db.query('sugar_records', orderBy: 'date DESC, time DESC');
      debugPrint('Fetched ${maps.length} sugar records.');
      return List.generate(maps.length, (i) {
        return SugarRecord.fromDbMap(maps[i]);
      });
    } catch (e, s) {
      debugPrint('Error fetching sugar records: $e\n$s');
      rethrow;
    }
  }

  // BP Record Operations
  Future<int> insertBPRecord(BPRecord record) async {
    final db = await database;
    final map = record.toDbMap();
    debugPrint('Inserting BP record: \$map');
    try {
      final id = await db.insert('bp_records', map);
      debugPrint('BP record inserted with id: \$id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting BP record: $e\n$s');
      rethrow; // Re-throw the error to be caught by the UI
    }
  }

  Future<List<BPRecord>> getBPRecords() async {
    final db = await database;
    debugPrint('Querying BP records...');
    try {
      final List<Map<String, dynamic>> maps = await db.query('bp_records', orderBy: 'date DESC, time DESC');
      debugPrint('Fetched ${maps.length} BP records.');
      return List.generate(maps.length, (i) {
        return BPRecord.fromDbMap(maps[i]);
      });
    } catch (e, s) {
      debugPrint('Error fetching BP records: $e\n$s');
      rethrow;
    }
  }
}