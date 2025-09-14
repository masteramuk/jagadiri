import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import '../providers/user_profile_provider.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class ReportGeneratorService {
  final DatabaseService _databaseService;
  final UserProfileProvider _userProfileProvider;

  ReportGeneratorService(this._databaseService, this._userProfileProvider);

  Future<Uint8List> generateReport({DateTime? startDate, DateTime? endDate}) async {
    final pdf = pw.Document();

    try {
      // 1. Directly fetch the user profile from the database
      // This ensures you get the data after the async call completes
      final UserProfile? userProfile = await _databaseService.getUserProfile();

      final List<BPRecord> bpRecords = await _databaseService.getBPRecordsDateRange(startDate: startDate, endDate: endDate);
      final List<SugarRecord> sugarRecords = await _databaseService.getSugarRecordsDateRange(startDate: startDate, endDate: endDate);

      // 2. Add a null check for the userProfile
      if (userProfile == null) {
        // Handle the case where no user profile exists
        throw Exception('User profile not found. Cannot generate report.');
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(userProfile, startDate, endDate),
              pw.SizedBox(height: 20),
              _buildSummarySection(bpRecords, sugarRecords),
              pw.SizedBox(height: 20),
              _buildAnalysisSection(bpRecords, sugarRecords),
              pw.SizedBox(height: 20),
              _buildDetailedDataSection(bpRecords, sugarRecords),
            ];
          },
        ),
      );

      return pdf.save();
    } catch (e, stackTrace) {
      print('Error generating PDF: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw the error so it can be caught by the caller (reports_screen.dart)
    }
  }

  pw.Widget _buildHeader(UserProfile? userProfile, DateTime? startDate, DateTime? endDate) {
    String dateRangeText = '';
    if (startDate != null && endDate != null) {
      dateRangeText = dateRangeText = 'Date Range: ${startDate != null ?
          DateFormat('dd-MMM-yyyy').format(startDate) : 'N/A'} - ${endDate != null ? DateFormat('dd-MMM-yyyy').format(endDate) : 'N/A'}';
      //'Date Range: ${startDate.toLocal().toString().split(' ')[0]} - ${endDate.toLocal().toString().split(' ')[0]}';
    } else if (startDate != null) {
      dateRangeText = 'From: ${startDate.toLocal().toString().split(' ')[0]}';
    } else if (endDate != null) {
      dateRangeText = 'To: ${endDate.toLocal().toString().split(' ')[0]}';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Health Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if (userProfile != null) ...[
          pw.Text('Name: ${userProfile.name}', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Date of Birth: ${userProfile.dob != null ? DateFormat('dd-MMM-yyyy').format(userProfile.dob!) : 'N/A'}', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Gender: ${userProfile.gender ?? 'N/A'}', style: pw.TextStyle(fontSize: 14)),
          // Add the following lines to display height, weight, sugar scenario, and BMI
          pw.Text(
              'Height: ${userProfile.height.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'cm' : 'in'}',
              style: pw.TextStyle(fontSize: 14)
          ),
          pw.Text(
              'Weight: ${userProfile.weight.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'kg' : 'lbs'}',
              style: pw.TextStyle(fontSize: 14)
          ),
          pw.Text(
              'BMI: ${userProfile != null ? (userProfile.measurementUnit == 'Metric' ? userProfile.weight / ((userProfile.height / 100) * (userProfile.height / 100)) : (userProfile.weight / (userProfile.height * userProfile.height)) * 703).toStringAsFixed(2) : 'N/A'}',
              style: pw.TextStyle(fontSize: 14)
          ),
          pw.Text(
              'Diabetic Status: ${userProfile.sugarScenario ?? 'N/A'}',
              style: pw.TextStyle(fontSize: 14)
          ),
        ],
        pw.Text(
          'Report Date: ${DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 14),
        ),
        if (dateRangeText.isNotEmpty) pw.Text(dateRangeText, style: pw.TextStyle(fontSize: 14)),
      ],
    );
  }

  pw.Widget _buildSummarySection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    // Calculate summary statistics
    double avgSystolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce((a, b) => a + b) / bpRecords.length : 0;
    double avgDiastolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce((a, b) => a + b) / bpRecords.length : 0;
    double avgPulse = bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce((a, b) => a + b) / bpRecords.length : 0;
    double avgSugar = sugarRecords.isNotEmpty ? sugarRecords.map((e) => e.value).reduce((a, b) => a + b) / sugarRecords.length : 0;

    int minSystolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce(min) : 0;
    int maxSystolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce(max) : 0;
    int minDiastolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce(min) : 0;
    int maxDiastolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce(max) : 0;
    int minPulse = bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce(min) : 0;
    int maxPulse = bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce(max) : 0;
    double minSugar = sugarRecords.isNotEmpty ? sugarRecords.map((e) => e.value).reduce(min) : 0;
    double maxSugar = sugarRecords.isNotEmpty ? sugarRecords.map((e) => e.value).reduce(max) : 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        _buildSectionSeparator(),
        pw.Text('Blood Pressure Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Average Systolic: ${avgSystolic.toStringAsFixed(1)}'),
        pw.Text('  Min Systolic: $minSystolic, Max Systolic: $maxSystolic'),
        pw.Text('  Average Diastolic: ${avgDiastolic.toStringAsFixed(1)}'),
        pw.Text('  Min Diastolic: $minDiastolic, Max Diastolic: $maxDiastolic'),
        pw.Text('  Average Pulse: ${avgPulse.toStringAsFixed(1)}'),
        pw.Text('  Min Pulse: $minPulse, Max Pulse: $maxPulse'),
        pw.SizedBox(height: 10),
        pw.Text('Blood Sugar Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Average Sugar: ${avgSugar.toStringAsFixed(1)}'),
        pw.Text('  Min Sugar: ${minSugar.toStringAsFixed(1)}, Max Sugar: ${maxSugar.toStringAsFixed(1)}'),
        pw.SizedBox(height: 10),
        pw.Text('Interpretation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Based on your records, your average blood pressure is ${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg and average blood sugar is ${avgSugar.toStringAsFixed(1)}.'),
        pw.Text('  (Further detailed interpretation and advice would go here based on specific health guidelines and user profile data.)'),
      ],
    );
  }

  pw.Widget _buildAnalysisSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    // Standard ranges (example values, ideally these would come from user profile or a configuration)
    const int normalSystolicMin = 90, normalSystolicMax = 120;
    const int normalDiastolicMin = 60, normalDiastolicMax = 80;
    const int normalPulseMin = 60, normalPulseMax = 100;
    const double normalSugarMin = 3.9, normalSugarMax = 5.5; // mmol/L (fasting)

    // Simple analysis for BP
    String bpAnalysis = 'No BP records available for analysis.';
    if (bpRecords.isNotEmpty) {
      double avgSystolic = bpRecords.map((e) => e.systolic).reduce((a, b) => a + b) / bpRecords.length;
      double avgDiastolic = bpRecords.map((e) => e.diastolic).reduce((a, b) => a + b) / bpRecords.length;

      if (avgSystolic > normalSystolicMax || avgDiastolic > normalDiastolicMax) {
        bpAnalysis = 'Your average blood pressure (${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg) is elevated. Consider consulting a healthcare professional.';
      } else if (avgSystolic < normalSystolicMin || avgDiastolic < normalDiastolicMin) {
        bpAnalysis = 'Your average blood pressure (${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg) is lower than normal. Consult a healthcare professional if you experience symptoms.';
      } else {
        bpAnalysis = 'Your average blood pressure (${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg) is within the normal range. Keep up the good work!';
      }
    }

    // Simple analysis for Sugar
    String sugarAnalysis = 'No Sugar records available for analysis.';
    if (sugarRecords.isNotEmpty) {
      double avgSugar = sugarRecords.map((e) => e.value).reduce((a, b) => a + b) / sugarRecords.length;
      if (avgSugar > normalSugarMax) {
        sugarAnalysis = 'Your average blood sugar (${avgSugar.toStringAsFixed(1)} mmol/L) is elevated. This could indicate prediabetes or diabetes. Please consult a doctor.';
      } else if (avgSugar < normalSugarMin) {
        sugarAnalysis = 'Your average blood sugar (${avgSugar.toStringAsFixed(1)} mmol/L) is lower than normal. This could indicate hypoglycemia. Please consult a doctor.';
      } else {
        sugarAnalysis = 'Your average blood sugar (${avgSugar.toStringAsFixed(1)} mmol/L) is within the normal range. Continue to monitor.';
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ANALYSIS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        _buildSectionSeparator(),
        pw.Text('Blood Pressure Analysis:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Normal Range: ${normalSystolicMin}-${normalSystolicMax}/${normalDiastolicMin}-${normalDiastolicMax} mmHg'),
        pw.Text('  $bpAnalysis'),
        pw.SizedBox(height: 10),
        pw.Text('Blood Sugar Analysis:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Normal Fasting Range: ${normalSugarMin}-${normalSugarMax} mmol/L'),
        pw.Text('  $sugarAnalysis'),
        pw.SizedBox(height: 10),
        pw.Text('Pulse Rate Analysis:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Normal Range: ${normalPulseMin}-${normalPulseMax} bpm'),
        pw.Text('  (Analysis for pulse rate would go here, similar to BP and Sugar)'),
      ],
    );
  }

  pw.Widget _buildDetailedDataSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('DETAILED DATA', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        _buildSectionSeparator(),
        pw.SizedBox(height: 10),
        if (bpRecords.isNotEmpty) ...[
          pw.Text('Blood Pressure Records:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Time', 'Time Name', 'Systolic', 'Diastolic', 'Pulse', 'Status'],
            data: bpRecords.map((record) => [
              record.date.toLocal().toString().split(' ')[0],
              record.time,
              record.timeName,
              record.systolic.toString(),
              record.diastolic.toString(),
              record.pulseRate.toString(),
              record.status,
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
        ],
        if (sugarRecords.isNotEmpty) ...[
          pw.Text('Blood Sugar Records:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Time', 'Meal Time Category', 'Meal Type', 'Sugar Level', 'Status'],
            data: sugarRecords.map((record) => [
              record.date.toLocal().toString().split(' ')[0],
              record.time,
              record.mealTimeCategory,
              record.mealType,
              record.value.toString(),
              record.status,
            ]).toList(),
          ),
        ],
        if (bpRecords.isEmpty && sugarRecords.isEmpty) 
          pw.Text('No detailed records available for the selected date range.'),
      ],
    );
  }

  pw.Widget _buildSectionSeparator() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: PdfColors.grey300,
    );
  }
}