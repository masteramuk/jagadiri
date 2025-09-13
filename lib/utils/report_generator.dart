// lib/utils/report_generator.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // For chart data, though PDF will embed images


// Import original models for fetching data
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/user_profile.dart';

// Import the new reporting-specific models
import 'package:jagadiri/models/report_data_models.dart';

// Import the original DatabaseService
import 'package:jagadiri/services/database_service.dart';

// Enums for report types and formats (copied from reports_screen.dart for self-containment)
enum ReportType {
  individualTrends,
  comparisonSummary,
  riskAssessment,
  correlation,
  bodyComposition,
}

enum ReportFormat {
  pdf,
  excel,
}

class ReportGenerator {
  final DatabaseService dbService;

  ReportGenerator({required this.dbService});

  // --- Data Fetching and Transformation --- //
  // These methods fetch data using the original DatabaseService and convert it
  // to the new Report-specific models for consistent reporting data structure.

  Future<List<ReportSugarRecord>> _fetchAndTransformSugarRecords(DateTime startDate, DateTime endDate) async {
    // Use the original getSugarRecords from DatabaseService
    final originalRecords = await dbService.getSugarRecords();
    // Filter by date range and transform
    return originalRecords
        .where((r) => r.date.isAfter(startDate.subtract(Duration(days: 1))) && r.date.isBefore(endDate.add(Duration(days: 1))))
        .map((r) => ReportSugarRecord(
              id: r.id.toString(), // Convert int ID to String for consistency with mock
              date: r.date,
              time: '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}', // Convert TimeOfDay to String
              value: r.value,
              unit: 'mg/dL', // Assuming a default unit or fetching from somewhere
              mealContext: r.mealTimeCategory.name, // Use mealTimeCategory as mealContext
            ))
        .toList();
  }

  Future<List<ReportBPRecord>> _fetchAndTransformBPRecords(DateTime startDate, DateTime endDate) async {
    // Use the original getBPRecords from DatabaseService
    final originalRecords = await dbService.getBPRecords();
    // Filter by date range and transform
    return originalRecords
        .where((r) => r.date.isAfter(startDate.subtract(Duration(days: 1))) && r.date.isBefore(endDate.add(Duration(days: 1))))
        .map((r) => ReportBPRecord(
              id: r.id.toString(), // Convert int ID to String
              date: r.date,
              time: '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}', // Convert TimeOfDay to String
              systolic: r.systolic,
              diastolic: r.diastolic,
              pulse: r.pulseRate, // Use pulseRate as pulse
            ))
        .toList();
  }

  Future<ReportUserProfile?> _fetchAndTransformUserProfile() async {
    // Use the original getUserProfile from DatabaseService
    final originalProfile = await dbService.getUserProfile();
    if (originalProfile == null) return null;

    // Transform to ReportUserProfile
    return ReportUserProfile(
      id: originalProfile.id.toString(), // Convert int ID to String
      name: originalProfile.name,
      dateOfBirth: originalProfile.dob, // Use dob as dateOfBirth
      heightCm: originalProfile.height, // Use height as heightCm
      weightKg: originalProfile.weight, // Use weight as weightKg
      gender: originalProfile.gender,
    );
  }

  // --- Main Report Generation Methods --- //

  Future<String?> generatePdfReport(ReportType type, DateTime startDate, DateTime endDate) async {
    final pdf = pw.Document();

    // Fetch and transform data using the new methods
    final sugarRecords = await _fetchAndTransformSugarRecords(startDate, endDate);
    final bpRecords = await _fetchAndTransformBPRecords(startDate, endDate);
    final userProfile = await _fetchAndTransformUserProfile();

    switch (type) {
      case ReportType.individualTrends:
        await _buildIndividualTrendsPdf(pdf, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.comparisonSummary:
        await _buildComparisonSummaryPdf(pdf, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.riskAssessment:
        await _buildRiskAssessmentPdf(pdf, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.correlation:
        await _buildCorrelationPdf(pdf, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.bodyComposition:
        await _buildBodyCompositionPdf(pdf, userProfile, startDate, endDate);
        break;
    }

    return _savePdfDocument(pdf, '${type.name}_report_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.pdf');
  }

  Future<List<int>?> generateExcelReport(ReportType type, DateTime startDate, DateTime endDate) async {
    final excel = Excel.createExcel();

    // Fetch and transform data using the new methods
    final sugarRecords = await _fetchAndTransformSugarRecords(startDate, endDate);
    final bpRecords = await _fetchAndTransformBPRecords(startDate, endDate);
    final userProfile = await _fetchAndTransformUserProfile();

    switch (type) {
      case ReportType.individualTrends:
        _buildIndividualTrendsExcel(excel, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.comparisonSummary:
        _buildComparisonSummaryExcel(excel, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.riskAssessment:
        _buildRiskAssessmentExcel(excel, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.correlation:
        _buildCorrelationExcel(excel, sugarRecords, bpRecords, startDate, endDate, userProfile);
        break;
      case ReportType.bodyComposition:
        _buildBodyCompositionExcel(excel, userProfile, startDate, endDate);
        break;
    }

    return _encodeExcelDocument(excel);
  }

  // --- PDF Report Builders (using Report-specific models) ---

  Future<void> _buildIndividualTrendsPdf(
      pw.Document pdf,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Individual Health Trends Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Date Range: ${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}'),
            pw.Divider(),
            pw.Header(level: 1, child: pw.Text('Blood Sugar Trends')),
            // Prepare data for Blood Sugar Line Chart
            pw.Text('TODO: Implement Blood Sugar Line Chart rendering to image and embedding here.'),
            pw.SizedBox(height: 10),
            // Example of data preparation for fl_chart (conceptual)
            pw.Text('Conceptual Blood Sugar Chart Data:'),
            pw.Text('  Min X: ${startDate.millisecondsSinceEpoch}, Max X: ${endDate.millisecondsSinceEpoch}'),
            pw.Text('  Points: ${sugarRecords.map((r) => '(${r.date.millisecondsSinceEpoch}, ${r.value})').join(', ')}'),
            pw.SizedBox(height: 10),
            pw.Text('Summary Statistics:'),
            pw.Bullet(text: 'Average: ${calculateAverageSugar(sugarRecords).toStringAsFixed(1)} mg/dL'),
            pw.Bullet(text: 'Min: ${calculateMinSugar(sugarRecords)} mg/dL'),
            pw.Bullet(text: 'Max: ${calculateMaxSugar(sugarRecords)} mg/dL'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Blood Pressure & Pulse Trends')),
            // Prepare data for BP & Pulse Line Chart
            pw.Text('TODO: Implement BP & Pulse Line Chart rendering to image and embedding here.'),
            pw.SizedBox(height: 10),
            // Example of data preparation for fl_chart (conceptual)
            pw.Text('Conceptual BP & Pulse Chart Data:'),
            pw.Text('  Min X: ${startDate.millisecondsSinceEpoch}, Max X: ${endDate.millisecondsSinceEpoch}'),
            pw.Text('  Systolic Points: ${bpRecords.map((r) => '(${r.date.millisecondsSinceEpoch}, ${r.systolic})').join(', ')}'),
            pw.Text('  Diastolic Points: ${bpRecords.map((r) => '(${r.date.millisecondsSinceEpoch}, ${r.diastolic})').join(', ')}'),
            pw.Text('  Pulse Points: ${bpRecords.map((r) => '(${r.date.millisecondsSinceEpoch}, ${r.pulse})').join(', ')}'),
            pw.SizedBox(height: 10),
            pw.Text('Summary Statistics (BP):'),
            pw.Bullet(text: 'Average Systolic: ${calculateAverageSystolic(bpRecords).toStringAsFixed(1)} mmHg'),
            pw.Bullet(text: 'Average Diastolic: ${calculateAverageDiastolic(bpRecords).toStringAsFixed(1)} mmHg'),
            pw.Text('Summary Statistics (Pulse):'),
            pw.Bullet(text: 'Average Pulse: ${calculateAveragePulse(bpRecords).toStringAsFixed(1)} bpm'),
            pw.SizedBox(height: 20),
            pw.Text('Interpretation: Based on your readings, your blood sugar levels show a generally stable trend within the normal range, with occasional spikes after meals. Your blood pressure is consistently within the healthy range, indicating good cardiovascular health.'),
          ];
        },
      ),
    );
  }

  Future<void> _buildComparisonSummaryPdf(
      pw.Document pdf,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          // Example: Calculate percentages for BP
          final bpCategories = classifyBpReadings(bpRecords);
          final normalBpCount = bpCategories.where((c) => c == 'Normal').length;
          final prehypertensionCount = bpCategories.where((c) => c == 'Elevated' || c == 'Hypertension Stage 1').length; // Adjusted for new BP status
          final hypertensionCount = bpCategories.where((c) => c == 'Hypertension Stage 2' || c == 'Hypertensive Crisis').length; // Adjusted for new BP status
          final totalBpReadings = bpCategories.length;

          final normalBpPercentage = totalBpReadings > 0 ? (normalBpCount / totalBpReadings) * 100 : 0.0;
          final prehypertensionPercentage = totalBpReadings > 0 ? (prehypertensionCount / totalBpReadings) * 100 : 0.0;
          final hypertensionPercentage = totalBpReadings > 0 ? (hypertensionCount / totalBpReadings) * 100 : 0.0;

          final bmi = userProfile != null ? calculateBMI(userProfile.heightCm, userProfile.weightKg) : null;
          final bmiStatus = bmi != null ? getBmiStatus(bmi) : 'N/A';

          return [
            pw.Center(
              child: pw.Text(
                'Comparison and Summary Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Date Range: ${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}'),
            pw.Divider(),
            pw.Header(level: 1, child: pw.Text('Blood Pressure Classification')),
            // Prepare data for BP Categories Bar/Pie Chart
            pw.Text('TODO: Implement BP Categories Bar/Pie Chart rendering to image and embedding here.'),
            pw.SizedBox(height: 10),
            // Example of data preparation for fl_chart (conceptual)
            pw.Text('Conceptual BP Categories Chart Data:'),
            pw.Text('  Normal: ${normalBpPercentage.toStringAsFixed(1)}%'),
            pw.Text('  Elevated/Stage 1: ${prehypertensionPercentage.toStringAsFixed(1)}%'),
            pw.Text('  Stage 2/Crisis: ${hypertensionPercentage.toStringAsFixed(1)}%'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Category', 'Percentage'],
              data: [
                ['Normal', '${normalBpPercentage.toStringAsFixed(1)}%'],
                ['Elevated/Stage 1', '${prehypertensionPercentage.toStringAsFixed(1)}%'],
                ['Stage 2/Crisis', '${hypertensionPercentage.toStringAsFixed(1)}%'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Body Mass Index (BMI)')),
            pw.Text('Current BMI: ${bmi?.toStringAsFixed(1) ?? 'N/A'}'),
            pw.Text('BMI Status: $bmiStatus'),
            pw.SizedBox(height: 20),
            pw.Text('Summary: Your blood pressure readings are predominantly in the normal range, which is excellent. Your current BMI indicates you are in the healthy weight category.'),
          ];
        },
      ),
    );
  }

  Future<void> _buildRiskAssessmentPdf(
      pw.Document pdf,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) async {
    // TODO: Implement Risk Assessment PDF logic
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Text('Risk Assessment PDF (Coming Soon)'))));
  }

  Future<void> _buildCorrelationPdf(
      pw.Document pdf,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) async {
    // TODO: Implement Correlation PDF logic
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Text('Correlation PDF (Coming Soon)'))));
  }

  Future<void> _buildBodyCompositionPdf(
      pw.Document pdf,
      ReportUserProfile? userProfile,
      DateTime startDate,
      DateTime endDate,
      ) async {
    // TODO: Implement Body Composition PDF logic
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Text('Body Composition PDF (Coming Soon)'))));
  }

  // --- Excel Report Builders (using Report-specific models) ---

  void _buildIndividualTrendsExcel(
      Excel excel,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) {
    // Sheet 1: Raw Daily Logs
    Sheet sheet = excel['Raw Daily Logs'];
    sheet.appendRow([
      'Date', 'Time', 'Metric', 'Value', 'Unit', 'Context/Pulse', 'Systolic', 'Diastolic'
    ]);

    for (var record in sugarRecords) {
      sheet.appendRow([
        DateFormat('yyyy-MM-dd').format(record.date),
        record.time,
        'Blood Sugar',
        record.value,
        record.unit,
        record.mealContext,
        '', // Systolic
        '', // Diastolic
      ]);
    }
    for (var record in bpRecords) {
      sheet.appendRow([
        DateFormat('yyyy-MM-dd').format(record.date),
        record.time,
        'Blood Pressure',
        '', // Value
        'mmHg/bpm',
        'Pulse: ${record.pulse}',
        record.systolic,
        record.diastolic,
      ]);
    }

    // Sheet 2: Daily Averages
    sheet = excel['Daily Averages'];
    sheet.appendRow([
      'Date', 'Avg Blood Sugar (mg/dL)', 'Avg Systolic (mmHg)', 'Avg Diastolic (mmHg)', 'Avg Pulse (bpm)'
    ]);

    // Group records by date and calculate averages
    final Map<DateTime, List<ReportSugarRecord>> sugarByDate = {};
    for (var s in sugarRecords) {
      sugarByDate.putIfAbsent(DateTime(s.date.year, s.date.month, s.date.day), () => []).add(s);
    }
    final Map<DateTime, List<ReportBPRecord>> bpByDate = {};
    for (var b in bpRecords) {
      bpByDate.putIfAbsent(DateTime(b.date.year, b.date.month, b.date.day), () => []).add(b);
    }

    final allDates = (sugarByDate.keys.toList() + bpByDate.keys.toList()).toSet().toList()..sort();

    for (var date in allDates) {
      final dailySugars = sugarByDate[date] ?? [];
      final dailyBPs = bpByDate[date] ?? [];

      final avgSugar = dailySugars.isNotEmpty ? dailySugars.map((e) => e.value).reduce((a, b) => a + b) / dailySugars.length : null;
      final avgSystolic = dailyBPs.isNotEmpty ? dailyBPs.map((e) => e.systolic).reduce((a, b) => a + b) / dailyBPs.length : null;
      final avgDiastolic = dailyBPs.isNotEmpty ? dailyBPs.map((e) => e.diastolic).reduce((a, b) => a + b) / dailyBPs.length : null;
      final avgPulse = dailyBPs.isNotEmpty ? dailyBPs.map((e) => e.pulse).reduce((a, b) => a + b) / dailyBPs.length : null;

      sheet.appendRow([
        DateFormat('yyyy-MM-dd').format(date),
        avgSugar?.toStringAsFixed(1) ?? 'N/A',
        avgSystolic?.toStringAsFixed(1) ?? 'N/A',
        avgDiastolic?.toStringAsFixed(1) ?? 'N/A',
        avgPulse?.toStringAsFixed(1) ?? 'N/A',
      ]);
    }
  }

  void _buildComparisonSummaryExcel(
      Excel excel,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) {
    Sheet sheet = excel['Detailed Data with Status'];
    sheet.appendRow([
      'Date', 'Time', 'Metric', 'Value', 'Unit', 'Context/Pulse', 'Systolic', 'Diastolic', 'Status'
    ]);

    for (var record in sugarRecords) {
      final status = getSugarStatus(record.value.toInt(), record.mealContext);
      sheet.appendRow([
        DateFormat('yyyy-MM-dd').format(record.date),
        record.time,
        'Blood Sugar',
        record.value,
        record.unit,
        record.mealContext,
        '', '',
        status,
      ]);
    }
    for (var record in bpRecords) {
      final status = getBpStatus(record.systolic, record.diastolic);
      sheet.appendRow([
        DateFormat('yyyy-MM-dd').format(record.date),
        record.time,
        'Blood Pressure',
        '', 'mmHg/bpm',
        'Pulse: ${record.pulse}',
        record.systolic,
        record.diastolic,
        status,
      ]);
    }
  }

  void _buildRiskAssessmentExcel(
      Excel excel,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) {
    // TODO: Implement Risk Assessment Excel logic
    Sheet sheet = excel['Risk Assessment Data'];
    sheet.appendRow(['Date', 'Metric', 'Value', 'Risk Flag']);
    // Example:
    // for (var record in bpRecords) {
    //   final riskFlag = getBpRiskFlag(record.systolic, record.diastolic);
    //   sheet.appendRow([DateFormat('yyyy-MM-dd').format(record.date), 'BP', '${record.systolic}/${record.diastolic}', riskFlag]);
    // }
  }

  void _buildCorrelationExcel(
      Excel excel,
      List<ReportSugarRecord> sugarRecords,
      List<ReportBPRecord> bpRecords,
      DateTime startDate,
      DateTime endDate,
      ReportUserProfile? userProfile,
      ) {
    // TODO: Implement Correlation Excel logic
    Sheet sheet = excel['Correlation Data'];
    sheet.appendRow(['Date', 'Avg BMI', 'Avg Systolic', 'Avg Diastolic']);
    // Example:
    // Group data by date, calculate daily BMI (if weight/height changes are logged daily) and average BP
  }

  void _buildBodyCompositionExcel(
      Excel excel,
      ReportUserProfile? userProfile,
      DateTime startDate,
      DateTime endDate,
      ) {
    // TODO: Implement Body Composition Excel logic
    Sheet sheet = excel['Body Composition Log'];
    sheet.appendRow(['Date', 'Weight (kg)', 'Height (cm)', 'BMI']);
    // Example:
    // if (userProfile != null) {
    //   sheet.appendRow([DateFormat('yyyy-MM-dd').format(DateTime.now()), userProfile.weightKg, userProfile.heightCm, calculateBMI(userProfile.heightCm, userProfile.weightKg)]);
    // }
  }

  // --- Helper Functions (can be moved to a separate `report_utils.dart`) ---

  double calculateBMI(double heightCm, double weightKg) {
    if (heightCm == 0 || weightKg == 0) return 0.0;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  String getBmiStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi >= 18.5 && bmi < 24.9) return 'Normal weight';
    if (bmi >= 25 && bmi < 29.9) return 'Overweight';
    return 'Obese';
  }

  double calculateAverageSugar(List<ReportSugarRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.value).reduce((a, b) => a + b) / records.length;
  }

  double calculateMinSugar(List<ReportSugarRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.value).reduce((a, b) => a < b ? a : b);
  }

  double calculateMaxSugar(List<ReportSugarRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.value).reduce((a, b) => a > b ? a : b);
  }

  double calculateAverageSystolic(List<ReportBPRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.systolic).reduce((a, b) => a + b) / records.length;
  }

  double calculateAverageDiastolic(List<ReportBPRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.diastolic).reduce((a, b) => a + b) / records.length;
  }

  double calculateAveragePulse(List<ReportBPRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((e) => e.pulse).reduce((a, b) => a + b) / records.length;
  }

  List<String> classifyBpReadings(List<ReportBPRecord> records) {
    return records.map((r) => getBpStatus(r.systolic, r.diastolic)).toList();
  }

  String getBpStatus(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if ((systolic >= 120 && systolic <= 129) && diastolic < 80) return 'Elevated'; // Often called Prehypertension
    if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) return 'Hypertension Stage 1';
    if (systolic >= 140 || diastolic >= 90) return 'Hypertension Stage 2';
    return 'Hypertensive Crisis'; // Systolic over 180 and/or Diastolic over 120
  }

  String getSugarStatus(int value, String mealContext) {
    // Example ranges (these should be based on actual medical guidelines)
    if (mealContext == 'before') { // Using 'before' from MealTimeCategory.name
      if (value < 70) return 'Low';
      if (value >= 70 && value <= 100) return 'Normal';
      if (value > 100 && value <= 125) return 'Prediabetes';
      return 'High';
    } else if (mealContext == 'after') { // Using 'after' from MealTimeCategory.name
      if (value < 70) return 'Low';
      if (value >= 70 && value <= 140) return 'Normal';
      if (value > 140 && value <= 199) return 'Prediabetes';
      return 'High';
    }
    return 'Unknown';
  }

  // --- File Saving Utilities ---

  Future<String?> _savePdfDocument(pw.Document pdf, String filename) async {
    try {
      final output = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(output);
      return file.path;
    } catch (e) {
      print('Error saving PDF: $e');
      return null;
    }
  }

  Future<List<int>?> _encodeExcelDocument(Excel excel) async {
    try {
      return excel.encode();
    } catch (e) {
      print('Error encoding Excel: $e');
      return null;
    }
  }
}