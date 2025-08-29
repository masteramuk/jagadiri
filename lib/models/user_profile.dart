
class UserProfile {
  int? id;
  String name;
  DateTime dob;
  double height;
  double weight;
  double targetWeight;
  String measurementUnit; // 'Metric' or 'US'
  String? gender;
  String? exerciseFrequency;
  String? sugarScenario; // New field for sugar scenario

  // Calculated suitable metrics and targets
  double? suitableSugarMin;
  double? suitableSugarMax;
  int? suitableSystolicMin;
  int? suitableSystolicMax;
  int? suitableDiastolicMin;
  int? suitableDiastolicMax;
  int? suitablePulseMin;
  int? suitablePulseMax;
  double? dailyCalorieTarget;

  UserProfile({
    this.id,
    required this.name,
    required this.dob,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.measurementUnit,
    this.gender,
    this.exerciseFrequency,
    this.sugarScenario, // Add this line
    this.suitableSugarMin,
    this.suitableSugarMax,
    this.suitableSystolicMin,
    this.suitableSystolicMax,
    this.suitableDiastolicMin,
    this.suitableDiastolicMax,
    this.suitablePulseMin,
    this.suitablePulseMax,
    this.dailyCalorieTarget,
  });

  // Calculate BMI
  double get bmi {
    if (measurementUnit == 'Metric') {
      // BMI = weight (kg) / (height (m))^2
      return weight / ((height / 100) * (height / 100));
    } else {
      // BMI = (weight (lbs) / (height (inches))^2) * 703
      return (weight / (height * height)) * 703;
    }
  }

  // Convert UserProfile to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': dob.toIso8601String(),
      'height': height,
      'weight': weight,
      'targetWeight': targetWeight,
      'measurementUnit': measurementUnit,
      'gender': gender,
      'exerciseFrequency': exerciseFrequency,
      'sugarScenario': sugarScenario, // Add this line
      'suitableSugarMin': suitableSugarMin,
      'suitableSugarMax': suitableSugarMax,
      'suitableSystolicMin': suitableSystolicMin,
      'suitableSystolicMax': suitableSystolicMax,
      'suitableDiastolicMin': suitableDiastolicMin,
      'suitableDiastolicMax': suitableDiastolicMax,
      'suitablePulseMin': suitablePulseMin,
      'suitablePulseMax': suitablePulseMax,
      'dailyCalorieTarget': dailyCalorieTarget,
    };
  }

  // Create a UserProfile from a Map retrieved from the database
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'],
      dob: DateTime.parse(map['dob']),
      height: map['height'],
      weight: map['weight'],
      targetWeight: map['targetWeight'],
      measurementUnit: map['measurementUnit'],
      gender: map['gender'],
      exerciseFrequency: map['exerciseFrequency'],
      sugarScenario: map['sugarScenario'], // Add this line
      suitableSugarMin: map['suitableSugarMin'],
      suitableSugarMax: map['suitableSugarMax'],
      suitableSystolicMin: map['suitableSystolicMin'],
      suitableSystolicMax: map['suitableSystolicMax'],
      suitableDiastolicMin: map['suitableDiastolicMin'],
      suitableDiastolicMax: map['suitableDiastolicMax'],
      suitablePulseMin: map['suitablePulseMin'],
      suitablePulseMax: map['suitablePulseMax'],
      dailyCalorieTarget: map['dailyCalorieTarget'],
    );
  }
}
