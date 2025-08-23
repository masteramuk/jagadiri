import 'package:flutter/material.dart';

enum SugarStatus {
  good,
  normal,
  bad,
}

enum MealTimeCategory {
  before,
  after,
}

enum MealType {
  breakfast,
  midMorningSnack,
  lunch,
  midAfternoonSnack,
  dinner,
  supper,
  sahoor,
}

class SugarRecord {
  final int? id; // Nullable for new records before insertion
  final DateTime date;
  final TimeOfDay time;
  final MealTimeCategory mealTimeCategory;
  final MealType mealType;
  final double value;
  final SugarStatus status;

  SugarRecord({
    this.id,
    required this.date,
    required this.time,
    required this.mealTimeCategory,
    required this.mealType,
    required this.value,
    required this.status,
  });

  // Factory constructor to create a SugarRecord from a JSON map (for local storage)
  factory SugarRecord.fromJson(Map<String, dynamic> json) {
    return SugarRecord(
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['timeHour'], minute: json['timeMinute']),
      mealTimeCategory: MealTimeCategory.values.firstWhere(
          (e) => e.toString().split('.').last == json['mealTimeCategory']),
      mealType: MealType.values.firstWhere(
          (e) => e.toString().split('.').last == json['mealType']),
      value: json['value'],
      status: SugarStatus.values.firstWhere(
          (e) => e.toString().split('.').last == json['status']),
    );
  }

  // Method to convert SugarRecord to a JSON map (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'mealTimeCategory': mealTimeCategory.toString().split('.').last,
      'mealType': mealType.toString().split('.').last,
      'value': value,
      'status': status.toString().split('.').last,
    };
  }

  // Factory constructor to create a SugarRecord from a database map
  factory SugarRecord.fromDbMap(Map<String, dynamic> map) {
    return SugarRecord(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      time: TimeOfDay(hour: int.parse(map['time'].split(':')[0]), minute: int.parse(map['time'].split(':')[1])),
      mealTimeCategory: MealTimeCategory.values.firstWhere(
          (e) => e.toString().split('.').last == map['mealTimeCategory']),
      mealType: MealType.values.firstWhere(
          (e) => e.toString().split('.').last == map['mealType']),
      value: map['value'],
      status: SugarStatus.values.firstWhere(
          (e) => e.toString().split('.').last == map['status']),
    );
  }

  // Method to convert SugarRecord to a database map
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'mealTimeCategory': mealTimeCategory.toString().split('.').last,
      'mealType': mealType.toString().split('.').last,
      'value': value,
      'status': status.toString().split('.').last,
    };
  }

  static SugarStatus calculateSugarStatus(
    MealTimeCategory mealTimeCategory,
    double value,
  ) {
    // Clinical ranges (illustrative, consult medical guidelines for accuracy)
    // Assuming mg/dL for now. Conversion will be handled at display.

    if (mealTimeCategory == MealTimeCategory.before) {
      // Before meal (fasting or pre-meal)
      if (value < 70 || value > 130) {
        return SugarStatus.bad;
      } else if (value >= 70 && value <= 100) {
        return SugarStatus.good;
      } else {
        return SugarStatus.normal; // 101-130
      }
    } else { // After meal
      if (value > 180) {
        return SugarStatus.bad;
      } else if (value <= 140) {
        return SugarStatus.good;
      } else {
        return SugarStatus.normal; // 141-180
      }
    }
  }
}
