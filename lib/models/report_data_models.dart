// lib/models/report_data_models.dart

// Dedicated models for reporting to avoid conflicts with existing app models.
// These models are designed to match the structure of the mock data
// that would be fetched from Google Sheets for reporting purposes.

import 'package:flutter/material.dart'; // For TimeOfDay, though we'll use String for time

class ReportSugarRecord {
  final String? id;
  final DateTime date;
  final String time; // e.g., "08:00"
  final double value;
  final String unit; // e.g., "mg/dL"
  final String mealContext; // e.g., "Before Meal", "After Meal"

  ReportSugarRecord({
    this.id,
    required this.date,
    required this.time,
    required this.value,
    required this.unit,
    required this.mealContext,
  });

  // Factory constructor to create from a map (e.g., from Google Sheets data)
  factory ReportSugarRecord.fromMap(Map<String, dynamic> map) {
    return ReportSugarRecord(
      id: map['id'] as String?,
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date'].toString()),
      time: map['time'] as String,
      value: map['value'] as double,
      unit: map['unit'] as String,
      mealContext: map['mealContext'] as String,
    );
  }
}

class ReportBPRecord {
  final String? id;
  final DateTime date;
  final String time; // e.g., "09:00"
  final int systolic;
  final int diastolic;
  final int pulse; // Renamed from pulseRate for reporting clarity

  ReportBPRecord({
    this.id,
    required this.date,
    required this.time,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });

  // Factory constructor to create from a map (e.g., from Google Sheets data)
  factory ReportBPRecord.fromMap(Map<String, dynamic> map) {
    return ReportBPRecord(
      id: map['id'] as String?,
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date'].toString()),
      time: map['time'] as String,
      systolic: map['systolic'] as int,
      diastolic: map['diastolic'] as int,
      pulse: map['pulse'] as int,
    );
  }
}

class ReportUserProfile {
  final String? id;
  final String name;
  final DateTime dateOfBirth;
  final double heightCm; // Height in centimeters
  final double weightKg; // Weight in kilograms
  final String? gender;

  ReportUserProfile({
    this.id,
    required this.name,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    this.gender,
  });

  // Factory constructor to create from a map (e.g., from Google Sheets data)
  factory ReportUserProfile.fromMap(Map<String, dynamic> map) {
    return ReportUserProfile(
      id: map['id'] as String?,
      name: map['name'] as String,
      dateOfBirth: map['dateOfBirth'] is DateTime ? map['dateOfBirth'] : DateTime.parse(map['dateOfBirth'].toString()),
      heightCm: map['heightCm'] as double,
      weightKg: map['weightKg'] as double,
      gender: map['gender'] as String?,
    );
  }
}
