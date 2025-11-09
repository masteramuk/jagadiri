import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/sugar_reference.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

  // Service to interact with the local database.
class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Define the database version
  static const int _dbVersion = 13;

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
    await seedChartDescriptions(db);
    await seedNlgTemplates(db);
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
      case 10:
        await _addColumns(db, 'sugar_records', {'notes': 'TEXT'});
        break;
      case 11:
        await _addColumns(db, 'bp_records', {'notes': 'TEXT'});
        break;
      case 12:
        await _createTable(db, 'chart_descriptions', _chartDescriptionSchema);
        await seedChartDescriptions(db);
        break;
      case 13:
        await _createTable(db, 'nlg_templates', _nlgTemplatesSchema);
        await seedNlgTemplates(db);
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
    await _createTable(db, 'chart_descriptions', _chartDescriptionSchema);
    await _createTable(db, 'nlg_templates', _nlgTemplatesSchema);
  }

  // === Schema Definitions ===

  static const String _sugarRecordsSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date INTEGER,
    time TEXT,
    mealTimeCategory TEXT,
    mealType TEXT,
    value REAL,
    status TEXT,
    notes TEXT
  ''';

  static const String _bpRecordsSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date INTEGER,
    time TEXT,
    timeName TEXT,
    systolic INTEGER,
    diastolic INTEGER,
    pulseRate INTEGER,
    status TEXT,
    notes TEXT
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

  static const String _chartDescriptionSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chart_type TEXT NOT NULL,
    trend TEXT NOT NULL,
    description TEXT NOT NULL
  ''';

  static const String _nlgTemplatesSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL,
    template TEXT NOT NULL
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

  Future<List<SugarRecord>> getSugarRecordsDateRange({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 'date >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'sugar_records',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, time DESC',
    );
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

  Future<List<BPRecord>> getBPRecordsDateRange({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 'date >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'bp_records',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, time DESC',
    );
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

  // === Sample Data Operations ===
  Future<void> deleteSampleData() async {
    final db = await database;
    int sugarDeletions = await db.delete('sugar_records', where: 'notes = ?', whereArgs: ['sample_data']);
    int bpDeletions = await db.delete('bp_records', where: 'notes = ?', whereArgs: ['sample_data']);
    debugPrint('Deleted $sugarDeletions sample sugar records and $bpDeletions sample BP records.');
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

  Future<void> seedNlgTemplates(Database db) async {
    final batch = db.batch();
    final templates = {
      'glucose_high': [
        "Monitoring carb intake might help prevent these spikes. 📈",
        "Remember to check your levels after meals to understand their impact. 🤔",
        "Are these spikes related to specific foods or stress? Noting it down can help.",
      ],
      'glucose_low': [
        "Always have a quick-sugar source handy. Your safety is a priority! 🍬",
        "Be careful not to overtreat a low; recheck your levels in 15 minutes.",
        "Feeling shaky or dizzy? It might be a sign of a hypo. Please be safe.",
      ],
      'bp_unstable': [
        "This variability can be taxing. Aiming for consistency in diet and routine can help. ⚖️",
        "Factors like salt intake, stress, or even caffeine can cause these swings.",
        "Let's try to create a more stable environment for your heart.",
      ],
      'pulse_low': [
        "For athletes, a lower pulse can be a sign of great fitness! But if you feel dizzy, it's worth a check-up. 🏃",
        "Certain medications can lower heart rate. It's good to be aware.",
      ],
      'pulse_high': [
        "Stress, caffeine, or dehydration can sometimes elevate your pulse. ☕",
        "Notice if your heart races during rest; it could be a signal to slow down and breathe.",
      ],
      'glucose_trend_up': [
        "Let's review your diet and activity to see what might be causing this upward trend. Small changes can make a big difference. 💪",
        "An upward trend is a call to action. You have the power to steer it back down!",
      ],
      'glucose_trend_down': [
        "Whatever you're doing, it's working! Keep up the fantastic effort. 🎉",
        "This downward trend is a huge win for your long-term health. Celebrate it!",
      ],
      'glucose_stable': [
        "Consistency is key in diabetes management, and you are nailing it! 👏",
        "A stable trend is a sign of a balanced and healthy routine. Well done!",
      ],
      'glucose_fluctuation': [
        "Smoothing out these peaks and valleys can lead to better energy and health. Consider consistent carb timing. 🍽️",
        "Big swings can be tiring. Let's aim for a gentler wave.",
      ],
      't1_diabetic': [
        "Your diligence with insulin and carb counting is the cornerstone of your health.",
        "Navigating the T1 journey requires strength. You're doing great.",
      ],
      't2_diabetic': [
        "Every healthy meal and every step you take is a step towards reversing insulin resistance. Keep going! 🚶‍♀️",
        "Managing T2 is a marathon, not a sprint. Your consistent efforts are what count.",
      ],
    };

    templates.forEach((key, templates) {
      for (var template in templates) {
        batch.insert('nlg_templates', {
          'key': key,
          'template': template,
        });
      }
    });

    await batch.commit(noResult: true);
    debugPrint('NLG templates table seeded.');
  }

  Future<void> seedChartDescriptions(Database db) async {
    final batch = db.batch();
    final descriptions = {
      'Glucose': {
        'high': [
          'Your glucose levels are consistently elevated. Consider consulting a healthcare professional for dietary and lifestyle adjustments.',
          'Elevated glucose readings suggest a need for closer monitoring. Review your recent food intake and activity levels.',
          'A pattern of high glucose is observed. This may indicate insulin resistance or other metabolic concerns.',
          'Sustained high glucose levels can lead to long-term health complications. Proactive management is key.',
          'Noticeable spikes in glucose after meals. Evaluate carbohydrate intake and portion sizes.',
          'Your average glucose is above the recommended range. Focus on balanced nutrition and regular physical activity.',
          'Frequent high glucose readings. This trend requires attention to prevent further progression.',
          'Glucose levels are not within optimal range. Seek guidance on personalized dietary plans.',
          'Persistent hyperglycemia detected. Discuss potential medication adjustments with your doctor.',
          'Your body\'s glucose regulation appears challenged. Lifestyle modifications are highly recommended.',
        ],
        'low': [
          'Your glucose levels are occasionally dipping too low. Ensure regular meals and snacks to maintain stable blood sugar.',
          'Some low glucose readings are present. Be mindful of symptoms like dizziness or weakness and carry a quick source of sugar.',
          'Hypoglycemic episodes are noted. Discuss your medication and meal timing with your doctor.',
          'Frequent low glucose readings can be dangerous. Always have a rapid-acting carbohydrate source available.',
          'Noticeable drops in glucose before meals or during exercise. Adjust your pre-meal or pre-exercise nutrition.',
          'Your average glucose is below the recommended range. Ensure adequate caloric intake and consistent meal patterns.',
          'Recurrent low glucose levels. This trend requires attention to prevent adverse events.',
          'Glucose levels are not within optimal range. Seek guidance on personalized dietary plans.',
          'Persistent hypoglycemia detected. Discuss potential medication adjustments with your doctor.',
          'Your body\'s glucose regulation appears challenged. Lifestyle modifications are highly recommended.',
        ],
        'stable': [
          'Your glucose levels show good stability within the target range. Keep up the excellent work with your diet and exercise.',
          'Consistent glucose readings indicate effective management. Continue your current health regimen.',
          'Excellent glucose control observed. This trend is highly beneficial for long-term health.',
          'Your glucose levels are well-managed and within a healthy range. This is a positive indicator of your health.',
          'Remarkable stability in glucose readings. Your adherence to a healthy lifestyle is commendable.',
          'Optimal glucose balance achieved. This consistency supports overall well-being.',
          'Glucose levels are consistently within the desired range. Maintain your current health practices.',
          'A very favorable glucose profile. This reflects good metabolic health.',
          'Your glucose management is exemplary. Continue to prioritize your health.',
          'This stable glucose trend is a strong foundation for preventing future health issues.',
        ],
        'fluctuating': [
          'Significant fluctuations in glucose levels are apparent. Identifying triggers from diet, exercise, or stress could be beneficial.',
          'Your glucose readings are quite variable. A more consistent routine might help stabilize these levels.',
          'Wide swings in glucose are noted. This pattern can be challenging to manage and warrants further investigation.',
          'Erratic glucose patterns suggest a need for closer examination of daily habits. Consider a food and activity log.',
          'Unpredictable glucose spikes and drops. This variability can be taxing on your body.',
          'Your glucose levels are unstable. Work with a healthcare provider to pinpoint the causes.',
          'Frequent and large variations in glucose. This indicates a need for more precise management strategies.',
          'Glucose control is inconsistent. Review your medication, diet, and exercise for potential adjustments.',
          'The rollercoaster pattern of your glucose levels requires attention. Aim for smoother transitions.',
          'Your body\'s glucose response is unpredictable. A structured approach to diet and activity may help.',
        ],
        'improving': [
          'Your glucose trend shows positive improvement. Your efforts in managing your health are paying off.',
          'A downward trend towards healthier glucose levels is observed. Continue with your current strategies.',
          'Encouraging signs of better glucose control are visible. This is a great step towards your health goals.',
          'The recent data indicates a favorable shift in your glucose profile. Keep progressing with your healthy choices.',
          'Your glucose levels are gradually moving into a healthier range. This sustained effort is highly beneficial.',
          'Positive changes in glucose management are evident. Your dedication to health is yielding results.',
          'An improving glucose trend is a strong indicator of effective self-care. Celebrate your progress.',
          'Your glucose readings are becoming more favorable. This positive momentum should be maintained.',
          'The trajectory of your glucose levels is improving. This is a testament to your commitment.',
          'Continued improvement in glucose control. This is a significant achievement for your health.',
        ],
        'worsening': [
          'Your glucose trend indicates a worsening pattern. It\'s important to re-evaluate your management plan and seek medical advice.',
          'An upward trend in glucose levels is noted. This requires immediate attention to prevent further complications.',
          'The recent data suggests a decline in glucose control. Consider reviewing your diet, exercise, and medication adherence.',
          'A concerning upward shift in your glucose profile. Prompt action is needed to reverse this trend.',
          'Your glucose levels are gradually moving into an unhealthy range. This requires urgent attention.',
          'Negative changes in glucose management are evident. Reassess your current health practices.',
          'A worsening glucose trend is a strong indicator that adjustments are needed. Seek professional guidance.',
          'Your glucose readings are becoming less favorable. This negative momentum should be addressed.',
          'The trajectory of your glucose levels is worsening. This is a critical time to intervene.',
          'Continued deterioration in glucose control. This is a serious concern for your health.',
        ],
      },
      'Blood Pressure': {
        'high': [
          'Your blood pressure readings are consistently high. Regular monitoring and lifestyle changes are crucial.',
          'Elevated blood pressure is observed. Consult your doctor to discuss management strategies.',
          'A pattern of hypertension is noted. Reducing sodium intake and increasing physical activity can help.',
          'Sustained high blood pressure can lead to serious cardiovascular issues. Proactive management is essential.',
          'Noticeable spikes in blood pressure. Evaluate stress levels and dietary habits.',
          'Your average blood pressure is above the recommended range. Focus on heart-healthy nutrition and regular exercise.',
          'Frequent high blood pressure readings. This trend requires attention to prevent further complications.',
          'Blood pressure levels are not within optimal range. Seek guidance on personalized management plans.',
          'Persistent hypertension detected. Discuss potential medication adjustments with your doctor.',
          'Your cardiovascular system appears under strain. Lifestyle modifications are highly recommended.',
        ],
        'low': [
          'Some low blood pressure readings are present. Ensure adequate hydration and discuss with your doctor if symptoms occur.',
          'Hypotension episodes are noted. Be cautious when changing positions quickly.',
          'Your blood pressure is occasionally dipping too low. Review your medication and hydration habits.',
          'Frequent low blood pressure readings can cause dizziness and fatigue. Ensure proper fluid intake.',
          'Noticeable drops in blood pressure. This might be related to medication or dehydration.',
          'Your average blood pressure is below the recommended range. Ensure adequate fluid and electrolyte balance.',
          'Recurrent low blood pressure levels. This trend requires attention to prevent adverse events.',
          'Blood pressure levels are not within optimal range. Seek guidance on personalized management plans.',
          'Persistent hypotension detected. Discuss potential medication adjustments with your doctor.',
          'Your cardiovascular system appears under-perfused. Lifestyle modifications are highly recommended.',
        ],
        'stable': [
          'Your blood pressure levels show good stability within the target range. Maintain your healthy habits.',
          'Consistent blood pressure readings indicate effective management. Continue your current health regimen.',
          'Excellent blood pressure control observed. This trend is highly beneficial for cardiovascular health.',
          'Your blood pressure levels are well-managed and within a healthy range. This is a positive indicator of your health.',
          'Remarkable stability in blood pressure readings. Your adherence to a healthy lifestyle is commendable.',
          'Optimal blood pressure balance achieved. This consistency supports overall well-being.',
          'Blood pressure levels are consistently within the desired range. Maintain your current health practices.',
          'A very favorable blood pressure profile. This reflects good cardiovascular health.',
          'Your blood pressure management is exemplary. Continue to prioritize your heart health.',
          'This stable blood pressure trend is a strong foundation for preventing future health issues.',
        ],
        'fluctuating': [
          'Significant fluctuations in blood pressure are apparent. Stress, diet, and medication timing can influence these variations.',
          'Your blood pressure readings are quite variable. A more consistent routine might help stabilize these levels.',
          'Wide swings in blood pressure are noted. This pattern can be challenging to manage and warrants further investigation.',
          'Erratic blood pressure patterns suggest a need for closer examination of daily habits. Consider a stress management plan.',
          'Unpredictable blood pressure spikes and drops. This variability can be taxing on your cardiovascular system.',
          'Your blood pressure levels are unstable. Work with a healthcare provider to pinpoint the causes.',
          'Frequent and large variations in blood pressure. This indicates a need for more precise management strategies.',
          'Blood pressure control is inconsistent. Review your medication, diet, and exercise for potential adjustments.',
          'The rollercoaster pattern of your blood pressure levels requires attention. Aim for smoother transitions.',
          'Your cardiovascular response is unpredictable. A structured approach to stress and activity may help.',
        ],
        'improving': [
          'Your blood pressure trend shows positive improvement. Your efforts in managing your health are paying off.',
          'A downward trend towards healthier blood pressure levels is observed. Continue with your current strategies.',
          'Encouraging signs of better blood pressure control are visible. This is a great step towards your heart health.',
          'The recent data indicates a favorable shift in your blood pressure profile. Keep progressing with your healthy choices.',
          'Your blood pressure levels are gradually moving into a healthier range. This sustained effort is highly beneficial.',
          'Positive changes in blood pressure management are evident. Your dedication to health is yielding results.',
          'An improving blood pressure trend is a strong indicator of effective self-care. Celebrate your progress.',
          'Your blood pressure readings are becoming more favorable. This positive momentum should be maintained.',
          'The trajectory of your blood pressure levels is improving. This is a testament to your commitment.',
          'Continued improvement in blood pressure control. This is a significant achievement for your heart health.',
        ],
        'worsening': [
          'Your blood pressure trend indicates a worsening pattern. It\'s important to re-evaluate your management plan and seek medical advice.',
          'An upward trend in blood pressure levels is noted. This requires immediate attention to prevent further complications.',
          'The recent data suggests a decline in blood pressure control. Consider reviewing your diet, exercise, and medication adherence.',
          'A concerning upward shift in your blood pressure profile. Prompt action is needed to reverse this trend.',
          'Your blood pressure levels are gradually moving into an unhealthy range. This requires urgent attention.',
          'Negative changes in blood pressure management are evident. Reassess your current health practices.',
          'A worsening blood pressure trend is a strong indicator that adjustments are needed. Seek professional guidance.',
          'Your blood pressure readings are becoming less favorable. This negative momentum should be addressed.',
          'The trajectory of your blood pressure levels is worsening. This is a critical time to intervene.',
          'Continued deterioration in blood pressure control. This is a serious concern for your heart health.',
        ],
      },
      'Pulse': {
        'high': [
          'Your pulse rate is consistently elevated. Factors like stress, caffeine, or activity levels might be contributing.',
          'Elevated pulse readings are observed. If persistent, consult a healthcare professional.',
          'A pattern of high pulse rate is noted. Ensure adequate rest and hydration.',
          'Sustained high pulse rate can indicate increased cardiovascular demand. Monitor your activity and stress.',
          'Noticeable spikes in pulse rate. Evaluate your recent physical exertion or emotional state.',
          'Your average pulse rate is above the recommended range. Consider relaxation techniques and regular, moderate exercise.',
          'Frequent high pulse rate readings. This trend requires attention to identify underlying causes.',
          'Pulse rate levels are not within optimal range. Seek guidance on personalized management plans.',
          'Persistent tachycardia detected. Discuss potential medication adjustments with your doctor.',
          'Your heart rate response appears elevated. Lifestyle modifications are highly recommended.',
        ],
        'low': [
          'Some low pulse rate readings are present. If accompanied by symptoms, seek medical advice.',
          'Bradycardia episodes are noted. This might be normal for athletes, but otherwise warrants investigation.',
          'Your pulse rate is occasionally dipping too low. Review your medication and activity levels.',
          'Hypoglycemic episodes are noted. Discuss your medication and meal timing with your doctor.',
          'Frequent low pulse rate readings can cause dizziness and fatigue. Ensure proper fluid intake.',
          'Noticeable drops in pulse rate. This might be related to medication or a high level of fitness.',
          'Your average pulse rate is below the recommended range. If symptomatic, consult a healthcare provider.',
          'Recurrent low pulse rate levels. This trend requires attention to identify underlying causes.',
          'Pulse rate levels are not within optimal range. Seek guidance on personalized management plans.',
          'Persistent bradycardia detected. Discuss potential medication adjustments with your doctor.',
          'Your heart rate response appears suppressed. Lifestyle modifications are highly recommended.',
        ],
        'stable': [
          'Your pulse rate shows good stability within the target range. Maintain your healthy habits.',
          'Consistent pulse rate readings indicate effective management. Continue your current health regimen.',
          'Excellent pulse rate control observed. This trend is highly beneficial for cardiovascular health.',
          'Your pulse rate levels are well-managed and within a healthy range. This is a positive indicator of your health.',
          'Remarkable stability in pulse rate readings. Your adherence to a healthy lifestyle is commendable.',
          'Optimal pulse rate balance achieved. This consistency supports overall well-being.',
          'Pulse rate levels are consistently within the desired range. Maintain your current health practices.',
          'A very favorable pulse rate profile. This reflects good cardiovascular health.',
          'Your pulse rate management is exemplary. Continue to prioritize your heart health.',
          'This stable pulse rate trend is a strong foundation for preventing future health issues.',
        ],
        'fluctuating': [
          'Significant fluctuations in pulse rate are apparent. Stress, hydration, and activity levels can influence these variations.',
          'Your pulse rate readings are quite variable. A more consistent routine might help stabilize these levels.',
          'Wide swings in pulse rate are noted. This pattern can be challenging to manage and warrants further investigation.',
          'Erratic pulse rate patterns suggest a need for closer examination of daily habits. Consider stress reduction techniques.',
          'Unpredictable pulse rate spikes and drops. This variability can be taxing on your cardiovascular system.',
          'Your pulse rate levels are unstable. Work with a healthcare provider to pinpoint the causes.',
          'Frequent and large variations in pulse rate. This indicates a need for more precise management strategies.',
          'Pulse rate control is inconsistent. Review your medication, diet, and exercise for potential adjustments.',
          'The rollercoaster pattern of your pulse rate levels requires attention. Aim for smoother transitions.',
          'Your heart rate response is unpredictable. A structured approach to stress and activity may help.',
        ],
        'improving': [
          'Your pulse rate trend shows positive improvement. Your efforts in managing your health are paying off.',
          'A downward trend towards healthier pulse rate levels is observed. Continue with your current strategies.',
          'Encouraging signs of better pulse rate control are visible. This is a great step towards your heart health.',
          'The recent data indicates a favorable shift in your pulse rate profile. Keep progressing with your healthy choices.',
          'Your pulse rate levels are gradually moving into a healthier range. This sustained effort is highly beneficial.',
          'Positive changes in pulse rate management are evident. Your dedication to health is yielding results.',
          'An improving pulse rate trend is a strong indicator of effective self-care. Celebrate your progress.',
          'Your pulse rate readings are becoming more favorable. This positive momentum should be maintained.',
          'The trajectory of your pulse rate levels is improving. This is a testament to your commitment.',
          'Continued improvement in pulse rate control. This is a significant achievement for your heart health.',
        ],
        'worsening': [
          'Your pulse rate trend indicates a worsening pattern. It\'s important to re-evaluate your management plan and seek medical advice.',
          'An upward trend in pulse rate levels is noted. This requires immediate attention to prevent further complications.',
          'The recent data suggests a decline in pulse rate control. Consider reviewing your diet, exercise, and medication adherence.',
          'A concerning upward shift in your pulse rate profile. Prompt action is needed to reverse this trend.',
          'Your pulse rate levels are gradually moving into an unhealthy range. This requires urgent attention.',
          'Negative changes in pulse rate management are evident. Reassess your current health practices.',
          'A worsening pulse rate trend is a strong indicator that adjustments are needed. Seek professional guidance.',
          'Your pulse rate readings are becoming less favorable. This negative momentum should be addressed.',
          'The trajectory of your pulse rate levels is worsening. This is a critical time to intervene.',
          'Continued deterioration in pulse rate control. This is a serious concern for your heart health.',
        ],
      },
    };

    descriptions.forEach((chartType, trends) {
      trends.forEach((trend, descs) {
        for (var desc in descs) {
          batch.insert('chart_descriptions', {
            'chart_type': chartType,
            'trend': trend,
            'description': desc,
          });
        }
      });
    });

    await batch.commit(noResult: true);
    debugPrint('Chart descriptions table seeded.');
  }

  Future<Map<String, Map<String, List<String>>>> getChartDescriptions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('chart_descriptions');

    final Map<String, Map<String, List<String>>> chartDescriptions = {};

    for (var map in maps) {
      final chartType = map['chart_type'] as String;
      final trend = map['trend'] as String;
      final description = map['description'] as String;

      if (!chartDescriptions.containsKey(chartType)) {
        chartDescriptions[chartType] = {};
      }
      if (!chartDescriptions[chartType]!.containsKey(trend)) {
        chartDescriptions[chartType]![trend] = [];
      }
      chartDescriptions[chartType]![trend]!.add(description);
    }

    return chartDescriptions;
  }

  Future<Map<String, List<String>>> getNlgTemplates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('nlg_templates');

    final Map<String, List<String>> nlgTemplates = {};

    for (var map in maps) {
      final key = map['key'] as String;
      final template = map['template'] as String;

      if (!nlgTemplates.containsKey(key)) {
        nlgTemplates[key] = [];
      }
      nlgTemplates[key]!.add(template);
    }

    return nlgTemplates;
  }

  Future<void> generateAndInsertDummyData(int numRecords, DateTime startDate, DateTime endDate, String measurementUnit) async {
    final db = await database;
    final Random random = Random();

    for (int i = 0; i < numRecords; i++) {
      // Generate a random date within the date range
      final randomDay = random.nextInt(endDate.difference(startDate).inDays + 1);
      final randomDate = startDate.add(Duration(days: randomDay));

      // Generate a random time
      final randomTime = TimeOfDay(hour: random.nextInt(24), minute: random.nextInt(60));

      // Generate a random sugar value based on the measurement unit
      double sugarValue;
      if (measurementUnit == 'Metric') {
        sugarValue = 3.0 + random.nextDouble() * 12.0; // Range for mmol/L
      } else { // US units
        sugarValue = 70 + random.nextDouble() * 130; // Range for mg/dL
      }

      // Generate a random sugar record
      final sugarRecord = SugarRecord(
        date: randomDate,
        time: randomTime,
        mealTimeCategory: MealTimeCategory.values[random.nextInt(MealTimeCategory.values.length)],
        mealType: MealType.values[random.nextInt(MealType.values.length)],
        value: sugarValue,
        status: SugarStatus.values[random.nextInt(SugarStatus.values.length)],
        notes: 'sample_data',
      );
      await db.insert('sugar_records', sugarRecord.toDbMap());

      // Generate a random BP record
      final bpRecord = BPRecord(
        date: randomDate,
        time: randomTime,
        timeName: BPTimeName.values[random.nextInt(BPTimeName.values.length)],
        systolic: 100 + random.nextInt(80), // Random value between 100 and 180
        diastolic: 60 + random.nextInt(40), // Random value between 60 and 100
        pulseRate: 60 + random.nextInt(40), // Random value between 60 and 100
        status: BPStatus.values[random.nextInt(BPStatus.values.length)],
        notes: 'sample_data',
      );
      await db.insert('bp_records', bpRecord.toDbMap());
    }
  }

    }