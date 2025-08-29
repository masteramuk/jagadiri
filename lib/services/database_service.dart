
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/models/sugar_ref_model.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Define the database version
  static const int _dbVersion = 8;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final factory = databaseFactoryFfiWeb;
      return factory.openDatabase('jagadiri.db', options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ));
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'jagadiri.db');
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database tables for version $version...');
    await _createAllTables(db);
    await seedSugarReference(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    // Use a migration script approach for clarity and robustness
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      await _runMigration(db, i);
    }
  }

  Future<void> _runMigration(Database db, int version) async {
    debugPrint('Running migration for version $version');
    switch (version) {
      case 2:
        await _createTable(db, 'bp_records', _bpRecordsSchema);
        break;
      case 3:
        await _createTable(db, 'settings', _settingsSchema);
        break;
      case 4:
        await _createTable(db, 'user_profile', _userProfileSchemaV4);
        break;
      case 5:
        await _addColumns(db, 'user_profile', _userProfileSchemaV5Adds);
        break;
      case 6:
        await _addColumns(db, 'user_profile', _userProfileSchemaV6Adds);
        break;
      case 7:
        await _createTable(db, 'sugar_references', _sugarReferenceSchemaV7);
        await _addColumns(db, 'user_profile', _userProfileSchemaV7Adds);
        break;
      case 8:
        await _createTable(db, 'sugar_reference', _sugarReferenceSchema);
        await seedSugarReference(db);
        break;
      default:
        debugPrint('No migration found for version $version');
        break;
    }
  }

  // Centralized table creation
  Future<void> _createAllTables(Database db) async {
    await _createTable(db, 'sugar_records', _sugarRecordsSchema);
    await _createTable(db, 'bp_records', _bpRecordsSchema);
    await _createTable(db, 'settings', _settingsSchema);
    await _createTable(db, 'user_profile', _userProfileSchema);
    await _createTable(db, 'sugar_reference', _sugarReferenceSchema);
  }

  // === Schema Definitions ===

  static const String _sugarRecordsSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date INTEGER,
    time TEXT,
    mealTimeCategory TEXT,
    mealType TEXT,
    value REAL,
    status TEXT
  ''';

  static const String _bpRecordsSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date INTEGER,
    time TEXT,
    timeName TEXT,
    systolic INTEGER,
    diastolic INTEGER,
    pulseRate INTEGER,
    status TEXT
  ''';

  static const String _settingsSchema = '''
    key TEXT PRIMARY KEY,
    value TEXT
  ''';

  static const String _sugarReferenceSchema = '''
    id INTEGER PRIMARY KEY,
    scenario TEXT NOT NULL CHECK(scenario IN ('non-diabetic','prediabetes','diabetes-ada','severe-hyper','hypoglycaemia')),
    unit TEXT NOT NULL CHECK(unit IN ('mmol/L','mg/dL')),
    meal_time TEXT NOT NULL CHECK(meal_time IN ('fasting','non-fasting','any')),
    min_value REAL,
    max_value REAL
  ''';

  static const String _sugarReferenceSchemaV7 = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scenario TEXT NOT NULL,
    unit TEXT NOT NULL,
    meal_time TEXT NOT NULL,
    meal_type TEXT NOT NULL,
    min_value REAL NOT NULL,
    max_value REAL NOT NULL,
    created_at INTEGER
  ''';

  // Full User Profile Schema (latest version)
  static const String _userProfileSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    dob TEXT NOT NULL,
    height REAL NOT NULL,
    weight REAL NOT NULL,
    targetWeight REAL NOT NULL,
    measurementUnit TEXT NOT NULL,
    gender TEXT,
    exerciseFrequency TEXT,
    sugarScenario TEXT,
    suitableSugarMin REAL,
    suitableSugarMax REAL,
    suitableSystolicMin INTEGER,
    suitableSystolicMax INTEGER,
    suitableDiastolicMin INTEGER,
    suitableDiastolicMax INTEGER,
    suitablePulseMin INTEGER,
    suitablePulseMax INTEGER,
    dailyCalorieTarget REAL
  ''';

  // Schemas for migration steps
  static const String _userProfileSchemaV4 = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    dob TEXT,
    height REAL,
    weight REAL,
    targetWeight REAL,
    measurementUnit TEXT
  ''';

  static const Map<String, String> _userProfileSchemaV5Adds = {
    'suitableSugarMin': 'REAL',
    'suitableSugarMax': 'REAL',
    'suitableSystolicMin': 'INTEGER',
    'suitableSystolicMax': 'INTEGER',
    'suitableDiastolicMin': 'INTEGER',
    'suitableDiastolicMax': 'INTEGER',
    'suitablePulseMin': 'INTEGER',
    'suitablePulseMax': 'INTEGER',
    'dailyCalorieTarget': 'REAL',
  };

  static const Map<String, String> _userProfileSchemaV6Adds = {
    'gender': 'TEXT',
    'exerciseFrequency': 'TEXT',
  };

  static const Map<String, String> _userProfileSchemaV7Adds = {
    'sugarScenario': 'TEXT',
  };


  // === Helper Methods for Schema Modification ===

  Future<void> _createTable(Database db, String tableName, String columns) async {
    try {
      await db.execute('CREATE TABLE IF NOT EXISTS $tableName($columns)');
      debugPrint('$tableName table created or already exists.');
    } catch (e) {
      debugPrint('Error creating table $tableName: $e');
    }
  }

  Future<void> _addColumns(Database db, String tableName, Map<String, String> columns) async {
    final List<Map<String, dynamic>> tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final Set<String> existingColumns = tableInfo.map((col) => col['name'] as String).toSet();

    for (final entry in columns.entries) {
      if (!existingColumns.contains(entry.key)) {
        try {
          await db.execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
          debugPrint('Added column ${entry.key} to $tableName.');
        } catch (e) {
          debugPrint('Error adding column ${entry.key} to $tableName: $e');
        }
      }
    }
  }

  // === Sugar Record Operations ===
  Future<int> insertSugarRecord(SugarRecord record) async {
    final db = await database;
    return await db.insert('sugar_records', record.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SugarRecord>> getSugarRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sugar_records', orderBy: 'date DESC, time DESC');
    return maps.map((e) => SugarRecord.fromDbMap(e)).toList();
  }

  Future<int> updateSugarRecord(SugarRecord record) async {
    final db = await database;
    return await db.update('sugar_records', record.toDbMap(), where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deleteSugarRecord(int id) async {
    final db = await database;
    return await db.delete('sugar_records', where: 'id = ?', whereArgs: [id]);
  }

  // === BP Record Operations ===
  Future<int> insertBPRecord(BPRecord record) async {
    final db = await database;
    return await db.insert('bp_records', record.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BPRecord>> getBPRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bp_records', orderBy: 'date DESC, time DESC');
    return maps.map((e) => BPRecord.fromDbMap(e)).toList();
  }

  // === User Profile Operations ===
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profile', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_profile', limit: 1);
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.update('user_profile', profile.toMap(), where: 'id = ?', whereArgs: [profile.id]);
  }

  // === Settings Operations ===
  Future<void> insertSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // === Sugar Reference Operations ===
  Future<void> seedSugarReference(Database db) async {
    final rows = [
      {'id': 1, 'scenario': 'non-diabetic', 'unit': 'mmol/L', 'meal_time': 'fasting', 'min_value': 3.9, 'max_value': 5.5},
      {'id': 2, 'scenario': 'non-diabetic', 'unit': 'mmol/L', 'meal_time': 'non-fasting', 'min_value': 3.9, 'max_value': 7.8},
      {'id': 3, 'scenario': 'prediabetes', 'unit': 'mmol/L', 'meal_time': 'fasting', 'min_value': 5.6, 'max_value': 6.9},
      {'id': 4, 'scenario': 'prediabetes', 'unit': 'mmol/L', 'meal_time': 'non-fasting', 'min_value': 7.9, 'max_value': 11.0},
      {'id': 5, 'scenario': 'diabetes-ada', 'unit': 'mmol/L', 'meal_time': 'fasting', 'min_value': 4.4, 'max_value': 7.2},
      {'id': 6, 'scenario': 'diabetes-ada', 'unit': 'mmol/L', 'meal_time': 'non-fasting', 'min_value': 4.4, 'max_value': 10.0},
      {'id': 7, 'scenario': 'severe-hyper', 'unit': 'mmol/L', 'meal_time': 'any', 'min_value': 13.0, 'max_value': null},
      {'id': 8, 'scenario': 'hypoglycaemia', 'unit': 'mmol/L', 'meal_time': 'any', 'min_value': null, 'max_value': 3.9},
      {'id': 9, 'scenario': 'non-diabetic', 'unit': 'mg/dL', 'meal_time': 'fasting', 'min_value': 70, 'max_value': 100},
      {'id': 10, 'scenario': 'non-diabetic', 'unit': 'mg/dL', 'meal_time': 'non-fasting', 'min_value': 70, 'max_value': 140},
      {'id': 11, 'scenario': 'prediabetes', 'unit': 'mg/dL', 'meal_time': 'fasting', 'min_value': 101, 'max_value': 125},
      {'id': 12, 'scenario': 'prediabetes', 'unit': 'mg/dL', 'meal_time': 'non-fasting', 'min_value': 141, 'max_value': 200},
      {'id': 13, 'scenario': 'diabetes-ada', 'unit': 'mg/dL', 'meal_time': 'fasting', 'min_value': 80, 'max_value': 130},
      {'id': 14, 'scenario': 'diabetes-ada', 'unit': 'mg/dL', 'meal_time': 'non-fasting', 'min_value': 80, 'max_value': 180},
      {'id': 15, 'scenario': 'severe-hyper', 'unit': 'mg/dL', 'meal_time': 'any', 'min_value': 250, 'max_value': null},
      {'id': 16, 'scenario': 'hypoglycaemia', 'unit': 'mg/dL', 'meal_time': 'any', 'min_value': null, 'max_value': 70},
    ];
    for (final r in rows) {
      await db.insert('sugar_reference', r, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> updateSugarRef(SugarRefModel ref) async {
    final db = await database;
    await db.update('sugar_reference', ref.toMap(), where: 'id = ?', whereArgs: [ref.id]);
  }

  Future<List<SugarRefModel>> getSugarReferences(String unit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sugar_reference', where: 'unit = ?', whereArgs: [unit]);
    return maps.map((e) => SugarRefModel.fromMap(e)).toList();
  }

  Future<List<SugarRefModel>> getSugarReferencesByQuery({
    required String unit,
    required String scenario,
    String? mealTime,
  }) async {
    final db = await database;
    String whereClause = 'unit = ? AND scenario = ?';
    List<dynamic> whereArgs = [unit, scenario];

    if (mealTime != null && mealTime != 'any') {
      whereClause += ' AND meal_time = ?';
      whereArgs.add(mealTime);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'sugar_reference',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.map((map) => SugarRefModel.fromMap(map)).toList();
  }
}
