import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart';

Future<SugarStatus> analyseStatus({
  required List<SugarRecord> records,
  required String unit,
  required String userDiabetesType,
}) async {
  if (records.isEmpty) return SugarStatus.good;

  final db = DatabaseService();

  for (final r in records) {
    final key = r.mealTimeCategory == MealTimeCategory.before ? 'fasting' : 'non-fasting';
    final ref = await db.getSugarReferencesByQuery(
        unit: unit,
        scenario: userDiabetesType,
        mealTime: key,
    );

    if (ref.isEmpty) continue;

    final row = ref.first;
    if (row.min != null && r.value < row.min) return SugarStatus.low;
    if (row.max != null && r.value > row.max) return SugarStatus.high;
  }
  return SugarStatus.good;
}
