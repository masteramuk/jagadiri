import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
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
      // Ensure all tables exist
      await _createAllTables(db);
      return db;
    } else {
      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, 'jagadiri.db');
      return await openDatabase(
        dbPath,
        version: 6, // Increased to 6: v1=sugar, v2=bp, v3=settings, v4=user_profile (basic), v5=user_profile (enhanced), v6=user_profile(gender, exercise)
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  // Create all tables (used for web and initial setup)
  Future<void> _createAllTables(Database db) async {
    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dob TEXT NOT NULL,
        height REAL NOT NULL,
        weight REAL NOT NULL,
        targetWeight REAL NOT NULL,
        measurementUnit TEXT NOT NULL,
        gender TEXT,
        exerciseFrequency TEXT,
        suitableSugarMin REAL,
        suitableSugarMax REAL,
        suitableSystolicMin INTEGER,
        suitableSystolicMax INTEGER,
        suitableDiastolicMin INTEGER,
        suitableDiastolicMax INTEGER,
        suitablePulseMin INTEGER,
        suitablePulseMax INTEGER,
        dailyCalorieTarget REAL
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database tables (version $version)...');
    await _createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // v2: Add bp_records
      await db.execute('''
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
      debugPrint('bp_records table created.');
    }

    if (oldVersion < 3) {
      // v3: Add settings
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      debugPrint('settings table created.');
    }

    if (oldVersion < 4) {
      // v4: Add basic user_profile
      await db.execute('''
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
      debugPrint('user_profile table created (basic).');
    }

    if (oldVersion < 5) {
      // v5: Add enhanced columns to user_profile
      await _addColumnsIfNotExist(db, 'user_profile', {
        'suitableSugarMin': 'REAL',
        'suitableSugarMax': 'REAL',
        'suitableSystolicMin': 'INTEGER',
        'suitableSystolicMax': 'INTEGER',
        'suitableDiastolicMin': 'INTEGER',
        'suitableDiastolicMax': 'INTEGER',
        'suitablePulseMin': 'INTEGER',
        'suitablePulseMax': 'INTEGER',
        'dailyCalorieTarget': 'REAL',
      });
      debugPrint('Enhanced columns added to user_profile.');
    }

    if (oldVersion < 6) {
      // v6: Add gender and exerciseFrequency to user_profile
      await _addColumnsIfNotExist(db, 'user_profile', {
        'gender': 'TEXT',
        'exerciseFrequency': 'TEXT',
      });
      debugPrint('Added gender and exerciseFrequency to user_profile.');
    }
  }

  // Helper: Add columns if they don't exist
  Future<void> _addColumnsIfNotExist(
      Database db, String tableName, Map<String, String> columns) async {
    final List<Map<String, dynamic>> existingColumns =
    await db.rawQuery('PRAGMA table_info($tableName)');

    final Set<String> columnNames = {
      for (var col in existingColumns) col['name'] as String
    };

    for (final entry in columns.entries) {
      if (!columnNames.contains(entry.key)) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
        debugPrint('Added column ${entry.key} to $tableName.');
      }
    }
  }

  // === Sugar Record Operations ===
  Future<int> insertSugarRecord(SugarRecord record) async {
    final db = await database;
    final map = record.toDbMap();
    debugPrint('Inserting sugar record: $map');
    try {
      final id = await db.insert('sugar_records', map);
      debugPrint('Sugar record inserted with id: $id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting sugar record: $e\n$s');
      rethrow;
    }
  }

  Future<List<SugarRecord>> getSugarRecords() async {
    final db = await database;
    debugPrint('Querying sugar records...');
    try {
      final List<Map<String, dynamic>> maps =
      await db.query('sugar_records', orderBy: 'date DESC, time DESC');
      debugPrint('Fetched ${maps.length} sugar records.');
      return maps.map((e) => SugarRecord.fromDbMap(e)).toList();
    } catch (e, s) {
      debugPrint('Error fetching sugar records: $e\n$s');
      rethrow;
    }
  }

  Future<int> updateSugarRecord(SugarRecord record) async {
    final db = await database;
    final map = record.toDbMap();
    debugPrint('Updating sugar record: $map');
    try {
      final rowsAffected = await db.update(
        'sugar_records',
        map,
        where: 'id = ?',
        whereArgs: [record.id],
      );
      debugPrint('Sugar record updated. RowsAffected: $rowsAffected');
      return rowsAffected;
    } catch (e, s) {
      debugPrint('Error updating sugar record: $e\n$s');
      rethrow;
    }
  }

  Future<int> deleteSugarRecord(int id) async {
    final db = await database;
    debugPrint('Deleting sugar record with id: $id');
    try {
      final rowsAffected = await db.delete(
        'sugar_records',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Sugar record deleted. Rows affected: $rowsAffected');
      return rowsAffected;
    } catch (e, s) {
      debugPrint('Error deleting sugar record: $e\n$s');
      rethrow;
    }
  }

  // === BP Record Operations ===
  Future<int> insertBPRecord(BPRecord record) async {
    final db = await database;
    final map = record.toDbMap();
    debugPrint('Inserting BP record: $map');
    try {
      final id = await db.insert('bp_records', map);
      debugPrint('BP record inserted with id: $id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting BP record: $e\n$s');
      rethrow;
    }
  }

  Future<List<BPRecord>> getBPRecords() async {
    final db = await database;
    debugPrint('Querying BP records...');
    try {
      final List<Map<String, dynamic>> maps =
      await db.query('bp_records', orderBy: 'date DESC, time DESC');
      debugPrint('Fetched ${maps.length} BP records.');
      return maps.map((e) => BPRecord.fromDbMap(e)).toList();
    } catch (e, s) {
      debugPrint('Error fetching BP records: $e\n$s');
      rethrow;
    }
  }

  // === User Profile Operations ===
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    final map = profile.toMap();
    debugPrint('Inserting user profile: $map');
    try {
      final id = await db.insert(
        'user_profile',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('User profile inserted with id: $id');
      return id;
    } catch (e, s) {
      debugPrint('Error inserting user profile: $e\n$s');
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
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

  // === Settings Operations ===
  Future<void> insertSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Setting "$key" saved with value "$value".');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      final value = maps.first['value'] as String;
      debugPrint('Setting "$key" retrieved with value "$value".');
      return value;
    }
    debugPrint('Setting "$key" not found.');
    return null;
  }
}