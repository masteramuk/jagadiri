import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/utils/sugar_analysis.dart';
import 'package:jagadiri/models/sugar_reference.dart';
import 'dart:typed_data';
import 'database_service.dart';
import '../providers/user_profile_provider.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class IndHealthTrendReportGeneratorService {
  final DatabaseService _databaseService;
  final UserProfileProvider _userProfileProvider;

  IndHealthTrendReportGeneratorService(this._databaseService, this._userProfileProvider);

  Future<Uint8List> generateReport({DateTime? startDate, DateTime? endDate}) async {
    final pdf = pw.Document();

    try {
      // 1. Directly fetch the user profile from the database
      // This ensures you get the data after the async call completes
      final UserProfile? userProfile = await _databaseService.getUserProfile();

      final List<BPRecord> bpRecords = await _databaseService.getBPRecordsDateRange(startDate: startDate, endDate: endDate);
      final List<SugarRecord> sugarRecords = await _databaseService.getSugarRecordsDateRange(startDate: startDate, endDate: endDate);
      final List<SugarReference> sugarRefs = await _databaseService.getSugarReferencesScenario(userProfile?.sugarScenario ?? 'Non-Diabetic');

      // 2. Add a null check for the userProfile
      if (userProfile == null) {
        // Handle the case where no user profile exists
        throw Exception('User profile not found. Cannot generate report.');
      }

      // Generate the internet-based analysis text
      final String sugarAnalysisText = await _getInternetBasedSugarAnalysis(sugarRecords);
      final String bpAnalysisText = await _getInternetBasedBPAnalysis(bpRecords);


      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(userProfile, startDate, endDate),
              pw.SizedBox(height: 20),
              _buildSummarySection(userProfile, bpRecords, sugarRecords, sugarRefs, sugarAnalysisText, bpAnalysisText),
              pw.SizedBox(height: 20),
              _buildAnalysisSection(bpRecords, sugarRecords, bpAnalysisText),
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
      dateRangeText = 'Date Range: ${DateFormat('dd-MMM-yyyy').format(startDate)} - ${DateFormat('dd-MMM-yyyy').format(endDate)}';
    } else if (startDate != null) {
      dateRangeText = 'From: ${DateFormat('dd-MMM-yyyy').format(startDate)}';
    } else if (endDate != null) {
      dateRangeText = 'To: ${DateFormat('dd-MMM-yyyy').format(endDate)}';
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

  pw.Widget _buildSummarySection(UserProfile userProfile, List<BPRecord> bpRecords, List<SugarRecord> sugarRecords, List<SugarReference> sugarRefs, String sugarAnalysisText, String bpAnalysisText) {
    // Calculate summary statistics
    double avgSystolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce((a, b) => a + b) / bpRecords.length : 0;
    double avgDiastolic = bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce((a, b) => a + b) / bpRecords.length : 0;
    double avgPulse = bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce((a, b) => a + b) / bpRecords.length : 0;

    // Sugar specific calculations
    SugarRecord? minSugarRecord = sugarRecords.isNotEmpty ? sugarRecords.reduce((a, b) => a.value < b.value ? a : b) : null;
    SugarRecord? maxSugarRecord = sugarRecords.isNotEmpty ? sugarRecords.reduce((a, b) => a.value > b.value ? a : b) : null;
    double avgSugar = sugarRecords.isNotEmpty ? sugarRecords.map((e) => e.value).reduce((a, b) => a + b) / sugarRecords.length : 0;

    String sugarUnit = userProfile.measurementUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        _buildSectionSeparator(),
        pw.SizedBox(height: 10),

        // Blood Sugar Measurement Sub-section
        pw.Text('Blood Sugar Measurement', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),

        // Min, Max, Average Boxes for Blood Sugar
        if (sugarRecords.isNotEmpty) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSugarSummaryBox('Minimum', minSugarRecord!, sugarUnit, userProfile, sugarRefs),
              _buildSugarSummaryBox('Maximum', maxSugarRecord!, sugarUnit, userProfile, sugarRefs),
              _buildSugarSummaryBox(
                'Average',
                SugarRecord(
                  date: DateTime.now(),
                  time: TimeOfDay(hour: 0, minute: 0), // A valid TimeOfDay object
                  mealTimeCategory: MealTimeCategory.before, // A valid enum value
                  mealType: MealType.breakfast, // A valid enum value
                  value: avgSugar,
                  status: SugarStatus.good, // A valid enum value
                ),
                sugarUnit,
                userProfile,
                sugarRefs,
                isAverage: true,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _buildSectionSeparator(),
          pw.SizedBox(height: 10),

          // Last Record Capture
          _buildLastSugarRecord(sugarRecords.first, sugarUnit),
          pw.SizedBox(height: 10),

          // Trend Analysis
          pw.Text('Trend Analysis:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _getSugarTrendAnalysis(sugarRecords),
          pw.SizedBox(height: 10),

          // Internet-based Analysis (Placeholder for now)
          pw.Text('Analysis of the result', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('  $sugarAnalysisText'),
        ] else pw.Text('No sugar records available for summary.'),

        pw.SizedBox(height: 20),

        // Blood Pressure and Pulse Rate Measurement Sub-section (Placeholder)
        pw.Text('Blood Pressure and Pulse Rate Measurement', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('  $bpAnalysisText'),

        pw.SizedBox(height: 20),

        pw.Text('Blood Pressure Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Average Systolic: ${avgSystolic.toStringAsFixed(1)}'),
        pw.Text('  Min Systolic: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce(min) : 0}, Max Systolic: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.systolic).reduce(max) : 0}'),
        pw.Text('  Average Diastolic: ${avgDiastolic.toStringAsFixed(1)}'),
        pw.Text('  Min Diastolic: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce(min) : 0}, Max Diastolic: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.diastolic).reduce(max) : 0}'),
        pw.Text('  Average Pulse: ${avgPulse.toStringAsFixed(1)}'),
        pw.Text('  Min Pulse: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce(min) : 0}, Max Pulse: ${bpRecords.isNotEmpty ? bpRecords.map((e) => e.pulseRate).reduce(max) : 0}'),
        pw.SizedBox(height: 10),
        pw.Text('Blood Sugar Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Average Sugar: ${avgSugar.toStringAsFixed(1)}'),
        pw.Text('  Min Sugar: ${minSugarRecord?.value.toStringAsFixed(1) ?? 'N/A'}, Max Sugar: ${maxSugarRecord?.value.toStringAsFixed(1) ?? 'N/A'}'),
        pw.SizedBox(height: 10),
        pw.Text('Interpretation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('  Based on your records, your average blood pressure is ${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg and average blood sugar is ${avgSugar.toStringAsFixed(1)}.'),
        pw.Text('  (Further detailed interpretation and advice would go here based on specific health guidelines and user profile data.)'),
      ],
    );
  }

  pw.Widget _buildAnalysisSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords, String bpAnalysisText) {
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
              DateFormat('dd-MMM-yyyy').format(record.date),
              _formatTimeOfDay(record.time),
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
              DateFormat('dd-MMM-yyyy').format(record.date),
              _formatTimeOfDay(record.time),
              record.mealTimeCategory.name,
              record.mealType.name,
              record.value.toString(),
              record.status.name,
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

  // Helper to get sugar status information and SVG icon
  Map<String, dynamic> _getSugarStatusInfo(
      SugarRecord record, UserProfile userProfile, List<SugarReference> sugarRefs) {
    final ref = sugarRefs.firstWhere(
          (r) => r.mealTime == record.mealTimeCategory.name,
      orElse: () => sugarRefs.first, // Fallback if no specific ref found
    );

    final status = analyseStatus(
      records: [record],
      unit: userProfile.measurementUnit,
      ref: ref,
    );

    String statusText;
    String statusIconSvg;

    switch (status) {
      case SugarStatus.excellent:
        statusText = 'Excellent';
        statusIconSvg = _getSvgIconForStatus(SugarStatus.excellent);
        break;
      case SugarStatus.borderline:
        statusText = 'Borderline';
        statusIconSvg = _getSvgIconForStatus(SugarStatus.borderline);
        break;
      case SugarStatus.low:
        statusText = 'Low';
        statusIconSvg = _getSvgIconForStatus(SugarStatus.low);
        break;
      case SugarStatus.high:
        statusText = 'High';
        statusIconSvg = _getSvgIconForStatus(SugarStatus.high);
        break;
      default:
        statusText = 'Unknown';
        statusIconSvg = _getSvgIconForStatus(null); // Pass null to indicate an unknown status
    }
    return {'statusText': statusText, 'statusIconSvg': statusIconSvg};
  }

  // Helper to map SugarStatus to an SVG icon string
  String _getSvgIconForStatus(SugarStatus? status) {
    switch (status) {
      case SugarStatus.excellent:
        return '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="green" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
        </svg>
      ''';
      case SugarStatus.borderline:
        return '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="orange" d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
        </svg>
      ''';
      case SugarStatus.low:
        return '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="blue" d="M20 12l-1.41-1.41L13 15.17V4h-2v11.17l-5.58-5.59L4 12l8 8 8-8z"/>
        </svg>
      ''';
      case SugarStatus.high:
        return '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="red" d="M4 12l1.41 1.41L11 8.83V20h2V8.83l5.58 5.59L20 12l-8-8-8 8z"/>
        </svg>
      ''';
      default:
        return '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="grey" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.15-2.9L13.4 10.1c.36-.36.6-.86.6-1.4 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/>
        </svg>
      ''';
    }
  }

  pw.Widget _buildSugarSummaryBox(
      String title,
      SugarRecord record,
      String unit,
      UserProfile userProfile,
      List<SugarReference> sugarRefs,
      {bool isAverage = false}) {
    final statusInfo = _getSugarStatusInfo(record, userProfile, sugarRefs);
    final statusText = statusInfo['statusText'];
    final statusIconSvg = statusInfo['statusIconSvg'];

    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                pw.Text(
                  '${record.value.toStringAsFixed(1)} $unit',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 5),
                // Display the SVG icon for the status
                pw.SvgImage(
                  svg: statusIconSvg,
                  height: 28,
                  width: 28,
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(statusText, style: pw.TextStyle(fontSize: 12)),
            if (!isAverage) ...[
              pw.Text('Meal: ${record.mealType.name}'),
              pw.Text('Time: ${_formatTimeOfDay(record.time)}'),
            ] else ...[
              pw.Text('Meal: NA'),
              pw.Text('Time: NA'),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _buildLastSugarRecord(SugarRecord record, String unit) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Last Recorded Measurement:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Date: ${DateFormat('dd-MMM-yyyy').format(record.date)}'),
        pw.Text('Time: ${_formatTimeOfDay(record.time)}'),
        pw.Text('Value: ${record.value.toStringAsFixed(1)} $unit'),
        pw.Text('Meal Type: ${record.mealType.name}'),
        pw.Text('Meal Time: ${record.mealTimeCategory.name}'),
      ],
    );
  }

  pw.Widget _getSugarTrendAnalysis(List<SugarRecord> sugarRecords) {
    if (sugarRecords.length < 2) {
      return pw.Text('  Not enough data for trend analysis.');
    }

    final sortedRecords = List<SugarRecord>.from(sugarRecords)
      ..sort((a, b) {
        int dateComparison = a.date.compareTo(b.date);
        if (dateComparison != 0) return dateComparison;
        // Compare times for same-day records
        final aTime = a.time;
        final bTime = b.time;
        return aTime.hour.compareTo(bTime.hour) * 60 + aTime.minute.compareTo(bTime.minute);
      });

    final latestRecord = sortedRecords.last;
    final previousRecord = sortedRecords[sortedRecords.length - 2];

    String trendText;
    String trendIconSvg;

    // 48 px vector icons – drop-in replacement that renders crisp in PDF
    if (latestRecord.value < previousRecord.value) {
      trendText = 'Improving (value decreased)';
      trendIconSvg = '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="green" d="M16 4H8v2h8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-4 13l4-4 4 4z"/>
        </svg>
      ''';
    } else if (latestRecord.value > previousRecord.value) {
      trendText = 'Worsening (value increased)';
      trendIconSvg = '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="red" d="M16 20H8v-2h8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-4 7l4 4 4-4z"/>
        </svg>
      ''';
    } else {
      trendText = 'Stable (value unchanged)';
      trendIconSvg = '''
        <svg viewBox="0 0 24 24" width="48" height="48" xmlns="http://www.w3.org/2000/svg">
          <path fill="blue" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-5 13h10v-2H7z"/>
        </svg>
      ''';
    }

    return pw.Row(
      children: [
        pw.Text('  Trend: '),
        pw.SvgImage(
          svg: trendIconSvg,
          height: 12,
          width: 12,
        ),
        pw.SizedBox(width: 5),
        pw.Text(trendText),
      ],
    );
  }

  // A helper function to format TimeOfDay objects for the PDF.
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat('hh:mm a');
    return format.format(dt);
  }

  // New function to perform internet-based analysis for blood sugar
  Future<String> _getInternetBasedSugarAnalysis(List<SugarRecord> sugarRecords) async {
    if (sugarRecords.length < 2) {
      return 'Not enough data for a comprehensive internet-based analysis.';
    }

    final sortedRecords = List<SugarRecord>.from(sugarRecords)
      ..sort((a, b) => a.date.compareTo(b.date));

    final latestRecord = sortedRecords.last;
    final previousRecord = sortedRecords[sortedRecords.length - 2];

    String trend = 'stable';
    if (latestRecord.value > previousRecord.value) {
      trend = 'increasing';
    } else if (latestRecord.value < previousRecord.value) {
      trend = 'decreasing';
    }

    final String userQuery = "Explain the health implications of a $trend trend in blood sugar levels, and provide general advice on how to manage this trend. Use information from reputable health sources.";

    // This is a placeholder for the actual API call. You would integrate
    // a real API client here to send a query to a service (e.g., Gemini API)
    // with Google Search grounding enabled.
    // The response would be the synthesized analysis text.
    // Replace this with your actual implementation.
    return "Based on your records showing an **$trend** trend, here is a general analysis from reliable health sources. An $trend trend in blood sugar levels can be a sign of fluctuating glycemic control. It may be linked to changes in diet, physical activity, or stress. Consistently high or low levels can impact long-term health. It is recommended to maintain a balanced diet and regular exercise to help stabilize glucose levels. Always consult a healthcare professional for personalized advice and diagnosis.";
  }

  // New function to perform internet-based analysis for blood pressure
  Future<String> _getInternetBasedBPAnalysis(List<BPRecord> bpRecords) async {
    if (bpRecords.isEmpty) {
      return 'No BP records available for a comprehensive internet-based analysis.';
    }

    double avgSystolic = bpRecords.map((e) => e.systolic).reduce((a, b) => a + b) / bpRecords.length;
    double avgDiastolic = bpRecords.map((e) => e.diastolic).reduce((a, b) => a + b) / bpRecords.length;

    final String userQuery = "Explain the health implications of an average blood pressure of ${avgSystolic.toStringAsFixed(0)} over ${avgDiastolic.toStringAsFixed(0)} mmHg, and provide general advice on how to manage it. Use information from reputable health sources.";

    // This is a placeholder for the actual API call.
    // Replace this with your actual implementation.
    String analysis = '';
    if (avgSystolic >= 130 || avgDiastolic >= 80) {
      analysis = "Your average blood pressure of ${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg falls into the category of **Elevated Blood Pressure** or **Stage 1 Hypertension**, as defined by the American Heart Association. This can increase your risk of cardiovascular events over time. To help manage this, a healthcare professional may recommend lifestyle changes such as a low-sodium diet, regular physical activity, stress management, and maintaining a healthy weight.";
    } else {
      analysis = "Your average blood pressure of ${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)} mmHg is considered within the **Normal** range. Maintaining a healthy lifestyle with a balanced diet, regular exercise, and minimal stress is key to keeping your blood pressure in this range.";
    }

    return analysis;
  }
}
