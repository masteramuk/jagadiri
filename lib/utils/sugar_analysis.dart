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
    final ref = await db.getSugarReferenceByQuery(
        scenario: userDiabetesType,
        mealTime: r.mealTimeCategory,
    );

    if (ref == null) continue;

    if (unit == 'Metric') { // mmol/L
      if (r.value < ref.minMmolL) return SugarStatus.low;
      if (r.value > ref.maxMmolL) return SugarStatus.high;
    } else { // US (mg/dL)
      if (r.value < ref.minMgdL) return SugarStatus.low;
      if (r.value > ref.maxMgdL) return SugarStatus.high;
    }
  }
  return SugarStatus.good;
}
