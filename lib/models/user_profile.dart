import 'package:flutter/material.dart';

class UserProfile {
  int? id;
  String name;
  DateTime dob;
  double height;
  double weight;
  double targetWeight;
  String measurementUnit; // 'Metric' or 'US'

  UserProfile({
    this.id,
    required this.name,
    required this.dob,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.measurementUnit,
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
    );
  }
}
