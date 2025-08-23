import 'package:flutter/services.dart';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' show dirname;
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/user_profile.dart';
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
      final factory = databaseFactoryFfiWeb;
      final db = await factory.openDatabase('jagadiri.db');
      // Ensure tables are created for web if they don't exist
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS sugar_records(
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
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS bp_records(
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
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT
)
        '''
      );
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
        '''
      );
      return db;
    } else {
      String databasesPath = await getDatabasesPath();
      String dbPath = join(databasesPath, 'jagadiri.db');

      

      return await openDatabase(
        dbPath,
        version: 4, // Current database version
        onCreate: _onCreate, // Called when the database is first created
        onUpgrade: _onUpgrade, // Called when the database needs to be upgraded
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database tables...');
    await db.execute(
      '''
CREATE TABLE IF NOT EXISTS sugar_records(
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
CREATE TABLE IF NOT EXISTS bp_records(
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

    // Add settings table
    await db.execute(
      '''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT
)
      '''
    );
    debugPrint('settings table created.');

    // Add user_profile table
    await db.execute(
      '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
      '''
    );
    debugPrint('user_profile table created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version \$oldVersion to \$newVersion');
    if (oldVersion < 2) {
      // Drop the old sugar_records table and create the new one
      await db.execute('DROP TABLE IF EXISTS sugar_records');
      debugPrint('Old sugar_records table dropped.');
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS sugar_records(
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
    if (oldVersion < 3) { // New version for settings table
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT
)
        '''
      );
      debugPrint('settings table created during upgrade.');
    }
    if (oldVersion < 4) { // New version for user_profile table
      await db.execute(
        '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
        '''
      );
      debugPrint('user_profile table created during upgrade.');
    }
    // Add other migration steps for future versions here
  }

  // Sugar Record Operations
  Future<int> insertSugarRecord(SugarRecord record) async {
    final db = await database;
    await _ensureTableExists(db, 'sugar_records', '''
CREATE TABLE IF NOT EXISTS sugar_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  mealTimeCategory TEXT,
  mealType TEXT,
  value REAL,
  status TEXT
)
    ''');
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
    await _ensureTableExists(db, 'sugar_records', '''
CREATE TABLE IF NOT EXISTS sugar_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  time TEXT,
  mealTimeCategory TEXT,
  mealType TEXT,
  value REAL,
  status TEXT
)
    ''');
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
    await _ensureTableExists(db, 'bp_records', '''
CREATE TABLE IF NOT EXISTS bp_records(
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
    final map = record.toDbMap();
    debugPrint('Inserting BP record: $map');
    try {
      final id = await db.insert('bp_records', map);
      debugPrint('BP record inserted with id: $id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting BP record: $e\n$s');
      rethrow; // Re-throw the error to be caught by the UI
    }
  }

  Future<List<BPRecord>> getBPRecords() async {
    final db = await database;
    await _ensureTableExists(db, 'bp_records', '''
CREATE TABLE IF NOT EXISTS bp_records(
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

  // User Profile Operations
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    await _ensureTableExists(db, 'user_profile', '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
    ''');
    final map = profile.toMap();
    debugPrint('Inserting user profile: $map');
    try {
      final id = await db.insert('user_profile', map, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('User profile inserted with id: $id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting user profile: $e\n$s');
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    await _ensureTableExists(db, 'user_profile', '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
    ''');
    debugPrint('Querying user profile...');
    try {
      final List<Map<String, dynamic>> maps = await db.query('user_profile', limit: 1);
      if (maps.isNotEmpty) {
        debugPrint('Fetched user profile: ${maps.first}');
        return UserProfile.fromMap(maps.first);
      } else {
        debugPrint('User profile not found.');
        return null;
      }
    } catch (e, s) {
      debugPrint('Error fetching user profile: $e\n$s');
      rethrow;
    }
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    await _ensureTableExists(db, 'user_profile', '''
CREATE TABLE IF NOT EXISTS user_profile(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  dob TEXT,
  height REAL,
  weight REAL,
  targetWeight REAL,
  measurementUnit TEXT
)
    ''');
    final map = profile.toMap();
    debugPrint('Updating user profile: $map');
    try {
      final rowsAffected = await db.update(
        'user_profile',
        map,
        where: 'id = ?',
        whereArgs: [profile.id],
      );
      debugPrint('User profile updated. Rows affected: $rowsAffected');
      return rowsAffected;
    } catch (e, s) {
      debugPrint('Error updating user profile: $e\n$s');
      rethrow;
    }
  }

  // Settings Operations
  Future<void> insertSetting(String key, String value) async {
    final db = await database;
    await _ensureTableExists(db, 'settings', '''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT
)
    ''');
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Setting "$key" saved with value "$value".');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    await _ensureTableExists(db, 'settings', '''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT
)
    ''');
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      debugPrint('Setting "$key" retrieved with value "${maps.first['value']}".');
      return maps.first['value'] as String;
    }
    debugPrint('Setting "$key" not found.');
    return null;
  }

  Future<void> _ensureTableExists(Database db, String tableName, String createTableSql) async {
    final tableExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
    if (tableExists.isEmpty) {
      debugPrint('Table $tableName does not exist. Creating it now.');
      await db.execute(createTableSql);
    }
  }
}