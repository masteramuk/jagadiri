import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart';

Future<SugarStatus> analyseStatus({
  required List<SugarRecord> records,
  required String unit,
  required String userDiabetesType,
}) async {
  if (records.isEmpty) return SugarStatus.good; // Default status

  final db = DatabaseService();
  final totalValue = records.map((r) => r.value).reduce((a, b) => a + b);
  final averageValue = totalValue / records.length;

  // Assuming all records in the list share the same mealtime category for analysis
  final representativeRecord = records.first;
  final ref = await db.getSugarReferenceByQuery(
    scenario: userDiabetesType,
    mealTime: representativeRecord.mealTimeCategory,
  );

  if (ref == null) return SugarStatus.good; // Or some other default/error status

  double min, max;
  if (unit == 'Metric') { // mmol/L
    min = ref.minMmolL;
    max = ref.maxMmolL;
  } else { // mg/dL
    min = ref.minMgdL;
    max = ref.maxMgdL;
  }

  // Define the borderline threshold (e.g., 15% of the range)
  final range = max - min;
  final borderlineThreshold = range * 0.15;

  if (averageValue < min) {
    return SugarStatus.low;
  } else if (averageValue > max) {
    return SugarStatus.high;
  } else if (averageValue >= min && averageValue < min + borderlineThreshold) {
    return SugarStatus.borderline;
  } else if (averageValue > max - borderlineThreshold && averageValue <= max) {
    return SugarStatus.borderline;
  } else {
    return SugarStatus.excellent;
  }
}
