import 'package:flutter/material.dart';

enum SugarStatus {
  good,
  normal,
  bad,
}

class SugarRecord {
  final DateTime date;
  final TimeOfDay time;
  final double beforeBreakfast;
  final double afterBreakfast;
  final double beforeLunch;
  final double afterLunch;
  final double beforeDinner;
  final double afterDinner;
  final double beforeSleep;
  final SugarStatus status;

  SugarRecord({
    required this.date,
    required this.time,
    required this.beforeBreakfast,
    required this.afterBreakfast,
    required this.beforeLunch,
    required this.afterLunch,
    required this.beforeDinner,
    required this.afterDinner,
    required this.beforeSleep,
    required this.status,
  });

  // Factory constructor to create a SugarRecord from a map (e.g., from Google Sheets)
  factory SugarRecord.fromMap(Map<String, dynamic> map) {
    // Implement logic to parse date, time, and sugar values from map
    // and determine status based on predefined ranges.
    // This will be more detailed once Google Sheets integration is clearer.
    return SugarRecord(
      date: DateTime.parse(map['Date']),
      time: TimeOfDay(
          hour: int.parse(map['Time'].split(':')[0]),
          minute: int.parse(map['Time'].split(':')[1])),
      beforeBreakfast: double.parse(map['Before Breakfast']),
      afterBreakfast: double.parse(map['After Breakfast']),
      beforeLunch: double.parse(map['Before Lunch']),
      afterLunch: double.parse(map['After Lunch']),
      beforeDinner: double.parse(map['Before Dinner']),
      afterDinner: double.parse(map['After Dinner']),
      beforeSleep: double.parse(map['Before Sleep']),
      status: SugarStatus.good, // Placeholder, actual logic will be here
    );
  }

  // Method to convert SugarRecord to a map (e.g., for Google Sheets)
  Map<String, dynamic> toMap() {
    return {
      'Date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'Time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'Before Breakfast': beforeBreakfast,
      'After Breakfast': afterBreakfast,
      'Before Lunch': beforeLunch,
      'After Lunch': afterLunch,
      'Before Dinner': beforeDinner,
      'After Dinner': afterDinner,
      'Before Sleep': beforeSleep,
      'Status': status.toString().split('.').last,
    };
  }
}
