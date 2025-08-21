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
  final DateTime date;
  final TimeOfDay time;
  final BPTimeName timeName;
  final int systolic;
  final int diastolic;
  final int pulseRate;
  final BPStatus status;

  BPRecord({
    required this.date,
    required this.time,
    required this.timeName,
    required this.systolic,
    required this.diastolic,
    required this.pulseRate,
    required this.status,
  });

  // Factory constructor to create a BPRecord from a map (e.g., from Google Sheets)
  factory BPRecord.fromMap(Map<String, dynamic> map) {
    // Implement logic to parse date, time, and BP values from map
    // and determine status based on predefined ranges.
    // This will be more detailed once Google Sheets integration is clearer.
    return BPRecord(
      date: DateTime.parse(map['Date']),
      time: TimeOfDay(
          hour: int.parse(map['Time'].split(':')[0]),
          minute: int.parse(map['Time'].split(':')[1])),
      timeName: BPTimeName.values.firstWhere(
          (e) => e.toString().split('.').last == map['Time Name']),
      systolic: int.parse(map['Systolic']),
      diastolic: int.parse(map['Diastolic']),
      pulseRate: int.parse(map['Pulse Rate']),
      status: BPStatus.good, // Placeholder, actual logic will be here
    );
  }

  // Method to convert BPRecord to a map (e.g., for Google Sheets)
  Map<String, dynamic> toMap() {
    return {
      'Date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'Time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'Time Name': timeName.toString().split('.').last,
      'Systolic': systolic,
      'Diastolic': diastolic,
      'Pulse Rate': pulseRate,
      'Status': status.toString().split('.').last,
    };
  }
}
