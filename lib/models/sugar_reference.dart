import 'package:jagadiri/models/sugar_record.dart'; // For MealTimeCategory

class SugarReference {
  final int? id;
  final String scenario;
  final MealTimeCategory mealTime;
  final double minMmolL;
  final double maxMmolL;
  final double minMgdL;
  final double maxMgdL;

  SugarReference({
    this.id,
    required this.scenario,
    required this.mealTime,
    required this.minMmolL,
    required this.maxMmolL,
    required this.minMgdL,
    required this.maxMgdL,
  });

  factory SugarReference.fromMap(Map<String, dynamic> map) {
    return SugarReference(
      id: map['id'],
      scenario: map['scenario'],
      mealTime: MealTimeCategory.values.firstWhere((e) => e.name == map['meal_time']),
      minMmolL: map['min_mmolL'],
      maxMmolL: map['max_mmolL'],
      minMgdL: map['min_mgdL'],
      maxMgdL: map['max_mgdL'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scenario': scenario,
      'meal_time': mealTime.name,
      'min_mmolL': minMmolL,
      'max_mmolL': maxMmolL,
      'min_mgdL': minMgdL,
      'max_mgdL': maxMgdL,
    };
  }
}
