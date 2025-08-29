class SugarRefModel {
  final int id;
  final String scenario;
  final String unit;
  final String mealTime;
  final double min;
  final double max;

  SugarRefModel({
    required this.id,
    required this.scenario,
    required this.unit,
    required this.mealTime,
    required this.min,
    required this.max,
  });

  factory SugarRefModel.fromMap(Map<String, dynamic> map) {
    return SugarRefModel(
      id: map['id'],
      scenario: map['scenario'],
      unit: map['unit'],
      mealTime: map['meal_time'],
      min: map['min_value'],
      max: map['max_value'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scenario': scenario,
      'unit': unit,
      'meal_time': mealTime,
      'min_value': min,
      'max_value': max,
    };
  }
}
