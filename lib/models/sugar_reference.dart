import 'package:jagadiri/models/sugar_record.dart'; // For MealTimeCategory and MealType

class SugarReference {
  final int? id;
  final String scenario;
  final String unit;
  final MealTimeCategory mealTime;
  final MealType mealType;
  final double minValue;
  final double maxValue;
  final int? createdAt;

  SugarReference({
    this.id,
    required this.scenario,
    required this.unit,
    required this.mealTime,
    required this.mealType,
    required this.minValue,
    required this.maxValue,
    this.createdAt,
  });

  // Factory constructor to create a SugarReference from a database map
  factory SugarReference.fromDbMap(Map<String, dynamic> map) {
    return SugarReference(
      id: map['id'],
      scenario: map['scenario'],
      unit: map['unit'],
      mealTime: MealTimeCategory.values.firstWhere(
          (e) => e.toString().split('.').last == map['meal_time']),
      mealType: MealType.values.firstWhere(
          (e) => e.toString().split('.').last == map['meal_type']),
      minValue: map['min_value'],
      maxValue: map['max_value'],
      createdAt: map['created_at'],
    );
  }

  // Method to convert SugarReference to a database map
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'scenario': scenario,
      'unit': unit,
      'meal_time': mealTime.toString().split('.').last,
      'meal_type': mealType.toString().split('.').last,
      'min_value': minValue,
      'max_value': maxValue,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }
}