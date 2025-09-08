import 'package:flutter/foundation.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/sugar_reference.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Define the database version
  static const int _dbVersion = 9;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final factory = databaseFactoryFfiWeb;
      return factory.openDatabase('jagadiri.db',
          options: OpenDatabaseOptions(
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
        // This version was for the old sugar_reference table, now superseded by v9
        break;
      case 9:
        await db.execute('DROP TABLE IF EXISTS sugar_reference');
        await db.execute('DROP TABLE IF EXISTS sugar_references'); // Also drop the plural one if it exists
        await _createTable(db, 'sugar_reference', _sugarReferenceSchema);
        await seedSugarReference(db);
        break;
      default:
        debugPrint('No migration found for version $version');
        break;
    }
  }

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
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scenario TEXT NOT NULL,
    meal_time TEXT NOT NULL,
    min_mmolL REAL NOT NULL,
    max_mmolL REAL NOT NULL,
    min_mgdL REAL NOT NULL,
    max_mgdL REAL NOT NULL
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

  Future<void> _createTable(Database db, String tableName, String columns) async {
    try {
      await db.execute('CREATE TABLE IF NOT EXISTS $tableName($columns)');
      debugPrint('$tableName table created or already exists.');
    } catch (e) {
      debugPrint('Error creating table $tableName: $e');
    }
  }

  Future<void> _addColumns(
      Database db, String tableName, Map<String, String> columns) async {
    final List<Map<String, dynamic>> tableInfo =
        await db.rawQuery('PRAGMA table_info($tableName)');
    final Set<String> existingColumns =
        tableInfo.map((col) => col['name'] as String).toSet();

    for (final entry in columns.entries) {
      if (!existingColumns.contains(entry.key)) {
        try {
          await db
              .execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
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
    return await db.insert('sugar_records', record.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SugarRecord>> getSugarRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('sugar_records', orderBy: 'date DESC, time DESC');
    return maps.map((e) => SugarRecord.fromDbMap(e)).toList();
  }

  Future<int> updateSugarRecord(SugarRecord record) async {
    final db = await database;
    return await db.update('sugar_records', record.toDbMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deleteSugarRecord(int id) async {
    final db = await database;
    return await db.delete('sugar_records', where: 'id = ?', whereArgs: [id]);
  }

  // === BP Record Operations ===
  Future<int> insertBPRecord(BPRecord record) async {
    final db = await database;
    return await db.insert('bp_records', record.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BPRecord>> getBPRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('bp_records', orderBy: 'date DESC, time DESC');
    return maps.map((e) => BPRecord.fromDbMap(e)).toList();
  }

  Future<int> updateBPRecord(BPRecord record) async {
    final db = await database;
    return await db.update('bp_records', record.toDbMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deleteBPRecord(int id) async {
    final db = await database;
    return await db.delete('bp_records', where: 'id = ?', whereArgs: [id]);
  }

  // === User Profile Operations ===
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profile', profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.update('user_profile', profile.toMap(),
        where: 'id = ?', whereArgs: [profile.id]);
  }

  // === Settings Operations ===
  Future<void> insertSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // === Sugar Reference Operations ===
  Future<void> seedSugarReference(Database db) async {
    final batch = db.batch();
    final data = {
      'Non-Diabetic': {
        'before': {'mmolL': [3.9, 5.5], 'mgdL': [70, 99]},
        'after': {'mmolL': [0.0, 7.8], 'mgdL': [0, 140]},
      },
      'Prediabetes': {
        'before': {'mmolL': [5.6, 6.9], 'mgdL': [100, 125]},
        'after': {'mmolL': [7.8, 11.0], 'mgdL': [140, 199]},
      },
      'Diabetes-ADA': {
        'before': {'mmolL': [4.0, 7.2], 'mgdL': [70, 130]},
        'after': {'mmolL': [0.0, 10.0], 'mgdL': [0, 180]},
      },
      'Type 1 Diabetes': {
        'before': {'mmolL': [4.0, 7.0], 'mgdL': [70, 130]},
        'after': {'mmolL': [5.0, 10.0], 'mgdL': [90, 180]},
      },
      'Type 2 Diabetes': {
        'before': {'mmolL': [4.0, 7.0], 'mgdL': [70, 130]},
        'after': {'mmolL': [0.0, 10.0], 'mgdL': [0, 180]},
      },
      'Severe Hyper-glycaemia': {
        'before': {'mmolL': [11.1, 99.0], 'mgdL': [200, 999]},
        'after': {'mmolL': [11.1, 99.0], 'mgdL': [200, 999]},
      },
      'Hypoglycaemia': {
        'before': {'mmolL': [0.0, 3.9], 'mgdL': [0, 70]},
        'after': {'mmolL': [0.0, 3.9], 'mgdL': [0, 70]},
      },
    };

    data.forEach((scenario, mealTimes) {
      mealTimes.forEach((mealTime, values) {
        batch.insert('sugar_reference', {
          'scenario': scenario,
          'meal_time': mealTime,
          'min_mmolL': values['mmolL']![0],
          'max_mmolL': values['mmolL']![1],
          'min_mgdL': values['mgdL']![0],
          'max_mgdL': values['mgdL']![1],
        });
      });
    });

    await batch.commit(noResult: true);
    debugPrint('Sugar reference table seeded.');
  }

  Future<void> updateSugarRef(SugarReference ref) async {
    final db = await database;
    await db.update('sugar_reference', ref.toMap(),
        where: 'id = ?', whereArgs: [ref.id]);
  }

  Future<List<SugarReference>> getSugarReferences() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sugar_reference');
    return maps.map((e) => SugarReference.fromMap(e)).toList();
  }

  Future<List<SugarReference>> getSugarReferencesScenario(String sugarScenario) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sugar_reference',
      where: 'scenario = ?',          // SQL WHERE clause
      whereArgs: [sugarScenario],     // value(s) for the ? placeholder(s)
    );
    return maps.map((e) => SugarReference.fromMap(e)).toList();
  }

  Future<SugarReference?> getSugarReferenceByQuery({
    required String scenario,
    required MealTimeCategory mealTime,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sugar_reference',
      where: 'scenario = ? AND meal_time = ?',
      whereArgs: [scenario, mealTime.name],
    );

    if (maps.isNotEmpty) {
      return SugarReference.fromMap(maps.first);
    }
    return null;
  }
}