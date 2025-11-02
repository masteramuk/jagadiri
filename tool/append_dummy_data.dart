import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:flutter/material.dart';
import '../lib/models/bp_record.dart';
import '../lib/models/sugar_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> arguments) async {
  sqfliteFfiInit();

  final parser = ArgParser()
    ..addOption('records', defaultsTo: '10', help: 'Number of records to generate.')
    ..addOption('start-date', help: 'Start date in YYYY-MM-DD format.')
    ..addOption('end-date', help: 'End date in YYYY-MM-DD format.');

  final argResults = parser.parse(arguments);

  final int numRecords = int.parse(argResults['records']);
  final DateTime startDate = argResults['start-date'] != null
      ? DateTime.parse(argResults['start-date'])
      : DateTime.now().subtract(const Duration(days: 30));
  final DateTime endDate =
      argResults['end-date'] != null ? DateTime.parse(argResults['end-date']) : DateTime.now();

  var databaseFactory = databaseFactoryFfi;
  String path = 'assets/data/jagadiri.db';

  if (!await File(path).exists()) {
    print('Database not found at $path. Please run create_db.dart first.');
    return;
  }

  print('Opening existing database to append data...');
  Database db = await databaseFactory.openDatabase(path);

  print('Generating and inserting $numRecords dummy data records...');

  final Random random = Random();

  for (int i = 0; i < numRecords; i++) {
    // Generate a random date within the date range
    final randomDay = random.nextInt(endDate.difference(startDate).inDays + 1);
    final randomDate = startDate.add(Duration(days: randomDay));

    // Generate a random time
    final randomTime = DateTime(randomDate.year, randomDate.month, randomDate.day,
        random.nextInt(24), random.nextInt(60));

    //Extract the hour and minute to create a TimeOfDay object
    final TimeOfDay timeOfDay = TimeOfDay(
        hour: randomTime.hour,
        minute: randomTime.minute
    );

    // Generate a random sugar record
    final sugarRecord = SugarRecord(
      date: randomDate,
      time: timeOfDay,
      mealTimeCategory: MealTimeCategory.values[random.nextInt(MealTimeCategory.values.length)],
      mealType: 'Sample Meal',
      value: 70 + random.nextDouble() * 130, // Random value between 70 and 200
      status: SugarStatus.normal,
      notes: 'sample_data',
    );
    await db.insert('sugar_records', sugarRecord.toDbMap());

    // Generate a random BP record
    final bpRecord = BPRecord(
      date: randomDate,
      time: timeOfDay,
      timeName: BPTimeName.values[random.nextInt(BPTimeName.values.length)],
      systolic: 100 + random.nextInt(80), // Random value between 100 and 180
      diastolic: 60 + random.nextInt(40), // Random value between 60 and 100
      pulseRate: 60 + random.nextInt(40), // Random value between 60 and 100
      status: BPStatus.normal,
      notes: 'sample_data',
    );
    await db.insert('bp_records', bpRecord.toDbMap());
  }

  print('$numRecords dummy data records appended.');

  await db.close();
}