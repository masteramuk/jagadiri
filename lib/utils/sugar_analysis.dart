import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/sugar_reference.dart';
import 'package:jagadiri/services/database_service.dart';

Future<SugarStatus> analyseStatus({
  required List<SugarRecord> records,
  required String unit,
  String? sugarScenario, // New parameter for user's scenario
}) async {
  final db = DatabaseService();
  SugarStatus overallStatus = SugarStatus.good; // Initial assumption is good

  for (var record in records) {
    // 1. Check for Hypoglycaemia (critical low)
    final hypoReferences = await db.getSugarReferenceData(
      unit: unit,
      scenario: 'Hypoglycaemia', // Filter by scenario
      mealTime: 'ANY',
      mealType: 'ANY',
    );
    if (hypoReferences.isNotEmpty && record.value < hypoReferences.first.maxValue) {
      overallStatus = SugarStatus.low;
      break; // Found a critical low, no need to check further
    }

    // 2. Check for Severe-Hyper (critical high)
    final hyperReferences = await db.getSugarReferenceData(
      unit: unit,
      scenario: 'Severe-Hyper', // Filter by scenario
      mealTime: 'ANY',
      mealType: 'ANY',
    );
    if (hyperReferences.isNotEmpty && record.value > hyperReferences.first.minValue) {
      overallStatus = SugarStatus.high;
      break; // Found a critical high, no need to check further
    }

    // 3. If not in critical ranges, check scenario-specific ranges
    // Only proceed if a sugarScenario is provided
    if (sugarScenario != null) {
      List<SugarReference> references = await db.getSugarReferenceData(
        unit: unit,
        scenario: sugarScenario, // Filter by user's scenario
        mealTime: record.mealTimeCategory.name,
        mealType: record.mealType.name,
      );

      // If no specific reference for mealType, try with ANY meal_type for the scenario
      if (references.isEmpty) {
        references = await db.getSugarReferenceData(
          unit: unit,
          scenario: sugarScenario,
          mealTime: record.mealTimeCategory.name,
          mealType: 'ANY',
        );
      }

      // If still no specific reference, try with ANY meal_time and ANY meal_type for the scenario
      if (references.isEmpty) {
        references = await db.getSugarReferenceData(
          unit: unit,
          scenario: sugarScenario,
          mealTime: 'ANY',
          mealType: 'ANY',
        );
      }

      // If a scenario-specific reference is found, apply its logic
      if (references.isNotEmpty) {
        final SugarReference reference = references.first;
        if (record.value < reference.minValue) {
          overallStatus = SugarStatus.low;
          break;
        } else if (record.value > reference.maxValue) {
          overallStatus = SugarStatus.high;
          break;
        }
      }
    }
    // If no sugarScenario or no matching scenario-specific reference,
    // and not in critical ranges, overallStatus remains good.
  }

  return overallStatus;
}