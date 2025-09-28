import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();

  var databaseFactory = databaseFactoryFfi;
  String path = 'assets/data/jagadiri.db';

  if (!await File(path).exists()) {
    print('Database not found at $path. Please run create_db.dart first.');
    return;
  }

  print('Opening existing database to append data...');
  Database db = await databaseFactory.openDatabase(path);

  print('Reading and executing dummy data inserts...');
  String dummyDataSql = await File('dummy_data_inserts.sql').readAsString();
  int count = 0;
  for (final String sql in dummyDataSql.split(';')) {
    if (sql.trim().isNotEmpty) {
      await db.execute(sql);
      count++;
    }
  }
  print('$count SQL statements executed successfully.');
  print('Dummy data appended.');

  await db.close();
}
