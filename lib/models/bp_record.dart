import 'package:flutter/material.dart';

enum BPStatus {
  good,
  normal,
  bad,
}

enum BPTimeName {
  morning,
  afternoon,
  evening,
  night,
}

class BPRecord {
  final int? id; // Nullable for new records before insertion
  final DateTime date;
  final TimeOfDay time;
  final BPTimeName timeName;
  final int systolic;
  final int diastolic;
  final int pulseRate;
  final BPStatus status;

  BPRecord({
    this.id,
    required this.date,
    required this.time,
    required this.timeName,
    required this.systolic,
    required this.diastolic,
    required this.pulseRate,
    required this.status,
  });

  // Factory constructor to create a BPRecord from a JSON map (for local storage)
  factory BPRecord.fromJson(Map<String, dynamic> json) {
    return BPRecord(
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['timeHour'], minute: json['timeMinute']),
      timeName: BPTimeName.values.firstWhere(
          (e) => e.toString().split('.').last == json['timeName']),
      systolic: json['systolic'],
      diastolic: json['diastolic'],
      pulseRate: json['pulseRate'],
      status: BPStatus.values.firstWhere(
          (e) => e.toString().split('.').last == json['status']),
    );
  }

  // Method to convert BPRecord to a JSON map (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'timeName': timeName.toString().split('.').last,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulseRate': pulseRate,
      'status': status.toString().split('.').last,
    };
  }

  // Factory constructor to create a BPRecord from a database map
  factory BPRecord.fromDbMap(Map<String, dynamic> map) {
    return BPRecord(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      time: TimeOfDay(hour: int.parse(map['time'].split(':')[0]), minute: int.parse(map['time'].split(':')[1])),
      timeName: BPTimeName.values.firstWhere(
          (e) => e.toString().split('.').last == map['timeName']),
      systolic: map['systolic'],
      diastolic: map['diastolic'],
      pulseRate: map['pulseRate'],
      status: BPStatus.values.firstWhere(
          (e) => e.toString().split('.').last == map['status']),
    );
  }

  // Method to convert BPRecord to a database map
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'timeName': timeName.toString().split('.').last,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulseRate': pulseRate,
      'status': status.toString().split('.').last,
    };
  }

  static BPStatus calculateBPStatus(int systolic, int diastolic, int pulseRate) {
    // Clinical ranges (illustrative, consult medical guidelines for accuracy)
    // Normal: <120/80
    // Elevated: 120-129/<80
    // Hypertension Stage 1: 130-139 or 80-89
    // Hypertension Stage 2: >=140 or >=90
    // Hypertensive Crisis: >180 and/or >120

    if (systolic >= 180 || diastolic >= 120) {
      return BPStatus.bad; // Hypertensive Crisis
    } else if (systolic >= 140 || diastolic >= 90) {
      return BPStatus.bad; // Hypertension Stage 2
    } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return BPStatus.normal; // Hypertension Stage 1
    } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return BPStatus.normal; // Elevated
    } else if (systolic < 120 && diastolic < 80) {
      return BPStatus.good; // Normal
    }
    return BPStatus.normal; // Default for cases not explicitly covered
  }
}