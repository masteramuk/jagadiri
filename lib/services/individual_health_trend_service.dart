import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as _pdf;
import 'package:pdf/widgets.dart' as pw;
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';
import 'health_analysis_service.dart';
import 'individual_health_trend_chart_generator.dart';

class IndividualHealthTrendService {
  final HealthAnalysisService _analysisService = HealthAnalysisService();

  // --- PDF Styling Constants ---
  // Define colors to match the desired UI look
  final _pdf.PdfColor _healthReportBg = const _pdf.PdfColor.fromInt(0xFFBBDEFB); // Light Blue 200
  final _pdf.PdfColor _summaryBg = const _pdf.PdfColor.fromInt(0xFFF0F0F0); // Very Light Grey (Card background)
  final _pdf.PdfColor _analysisBg = const _pdf.PdfColor.fromInt(0xFFE8F5E9); // Light Green 50
  final _pdf.PdfColor _analysisTitleColor = const _pdf.PdfColor.fromInt(0xFF388E3C); // Dark Green

  // Common styles for the 'Card' look
  static const double _padding = 16.0;
  static const double _borderRadius = 8.0;
  static const double _lineSpacing = 1.5;

  /// Generates PDF for Individual Health Trends report.
  Future<pw.Document> generatePdf({
    required List<SugarRecord> sugarReadings,
    required List<BPRecord> bpReadings,
    required UserProfile userProfile,
    required Uint8List glucoseChartBytes,
    required Uint8List bpChartBytes,
    required Uint8List pulseChartBytes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Preload chart widgets
    final glucoseChartWidget = buildChartImage(
        'Glucose Trend', glucoseChartBytes);
    final bpChartWidget = buildChartImage(
        'Blood Pressure Trend', bpChartBytes);
    final pulseChartWidget = buildChartImage(
        'Pulse Trend', pulseChartBytes);

    final analysisText = _analysisService.generateAnalysisText(
      sugarReadings: sugarReadings,
      bpReadings: bpReadings,
      userProfile: userProfile,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _pdf.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // --- PAGE 1: HEADER & SUMMARY SECTIONS (should always fit on page 1) ---
            buildReportTitle(),
            pw.SizedBox(height: 16),
            buildHeader(userProfile, startDate, endDate),
            buildSummarySection(userProfile, bpReadings, sugarReadings),
            pw.NewPage(),
            // --- ANALYSIS SECTION: Wrapped to prevent orphaned section title/huge gaps ---
            buildAnalysisSection(analysisText),

            pw.SizedBox(height: 30),

            // --- TREND ANALYSIS SECTION: Grouped to prevent orphaned title ---
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Trend Analysis', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  if (sugarReadings.isNotEmpty) glucoseChartWidget,
                  if (sugarReadings.isNotEmpty) pw.SizedBox(height: 10),
                ]
            ),

            // Other charts follow
            if (bpReadings.isNotEmpty) bpChartWidget,
            if (bpReadings.isNotEmpty) pw.SizedBox(height: 10),

            if (bpReadings.isNotEmpty) pulseChartWidget,
            if (bpReadings.isNotEmpty) pw.SizedBox(height: 30),

            pw.NewPage(),
            // --- DETAILED DATA SECTION: Wrapped inside its own function to keep titles with tables ---
            buildDetailedDataSection(bpReadings, sugarReadings),
          ];
        },
      ),
    );

    return pdf;
  }

  // --- WIDGET BUILDING METHODS ---

  Future<Uint8List> generatePrintablePdf({
    required List<SugarRecord> sugarReadings,
    required List<BPRecord> bpReadings,
    required UserProfile userProfile,
    required Uint8List glucoseChartBytes,
    required Uint8List bpChartBytes,
    required Uint8List pulseChartBytes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final analysisText = _analysisService.generateAnalysisText(
      sugarReadings: sugarReadings,
      bpReadings: bpReadings,
      userProfile: userProfile,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _pdf.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            buildReportTitle(),
            pw.SizedBox(height: 16),
            buildHeader(userProfile, startDate, endDate),
            buildSummarySection(userProfile, bpReadings, sugarReadings),
            pw.NewPage(),
            buildAnalysisSection(analysisText),
            pw.SizedBox(height: 30),
            pw.NewPage(),
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Trend Analysis', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  if (sugarReadings.isNotEmpty) buildChartImage('Glucose Trend', glucoseChartBytes),
                  if (sugarReadings.isNotEmpty) pw.SizedBox(height: 10),
                ]
            ),
            pw.NewPage(),
            if (bpReadings.isNotEmpty) buildChartImage('Blood Pressure Trend', bpChartBytes),
            if (bpReadings.isNotEmpty) pw.SizedBox(height: 10),
            pw.NewPage(),
            if (bpReadings.isNotEmpty) buildChartImage('Pulse Trend', pulseChartBytes),
            if (bpReadings.isNotEmpty) pw.SizedBox(height: 30),
            pw.NewPage(),
            buildDetailedDataSection(bpReadings, sugarReadings),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget buildReportTitle() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('🩺', style: pw.TextStyle(fontSize: 40)),
        pw.SizedBox(height: 8),
        pw.Text(
          'Individual Health Trend Analysis Report',
          style: pw.TextStyle(
              fontSize: 22, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Report Generated on ${DateFormat.yMMMd().format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget buildHeader(UserProfile? userProfile, DateTime? startDate, DateTime? endDate) {
    String dateRangeText = '';
    if (startDate != null && endDate != null) {
      dateRangeText = 'Date Range: ${_formatDate(startDate)} - ${_formatDate(endDate)}';
    } else if (startDate != null) {
      dateRangeText = 'From: ${_formatDate(startDate)}';
    } else if (endDate != null) {
      dateRangeText = 'To: ${_formatDate(endDate)}';
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(_padding),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _healthReportBg,
        borderRadius: pw.BorderRadius.circular(_borderRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Health Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 10, thickness: 1),
          if (userProfile != null) ...[
            pw.Text('Name: ${userProfile.name}'),
            pw.Text('Date of Birth: ${userProfile.dob != null ? _formatDate(userProfile.dob!) : 'N/A'}'),
            pw.Text('Gender: ${userProfile.gender ?? 'N/A'}'),
            pw.Text('Height: ${userProfile.height.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'cm' : 'in'}'),
            pw.Text('Weight: ${userProfile.weight.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'kg' : 'lbs'}'),
            pw.Text('BMI: ${_calculateBMI(userProfile).toStringAsFixed(1)}'),
            pw.Text('Diabetic Status: ${userProfile.sugarScenario ?? 'N/A'}'),
          ],
          pw.Divider(height: 10, thickness: 1),
          pw.Text('Report Date: ${_formatDateTime(DateTime.now())}'),
          if (dateRangeText.isNotEmpty) pw.Text(dateRangeText),
        ],
      ),
    );
  }

  pw.Widget buildSummarySection(UserProfile userProfile, List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(_padding),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _summaryBg,
        borderRadius: pw.BorderRadius.circular(_borderRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 10, thickness: 1),
          if (sugarRecords.isNotEmpty) ...[
            pw.Text(
                'Avg Glucose: ${_avg(sugarRecords, (r) => r.value as num).toStringAsFixed(1)} mg/dL'),
            pw.Text('Min: ${_min(sugarRecords, (r) => r.value as num).toStringAsFixed(1)} | Max: ${_max(sugarRecords, (r) => r.value as num).toStringAsFixed(1)}'),
          ],
          if (bpRecords.isNotEmpty) ...[
            pw.Text('Avg BP: ${_avg(bpRecords, (r) => r.systolic as num).round()}/${_avg(bpRecords, (r) => r.diastolic as num).round()} mmHg'),
            pw.Text('Avg Pulse: ${_avg(bpRecords, (r) => r.pulseRate as num).round()} bpm'),
          ],
        ],
      ),
    );
  }

  pw.Widget buildAnalysisSection(String analysisText) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(_padding),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _analysisBg,
        borderRadius: pw.BorderRadius.circular(_borderRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('HEALTH ANALYSIS', style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _analysisTitleColor,
          )),
          pw.Divider(height: 10, thickness: 1),
          pw.Paragraph(
            text: analysisText,
            style: const pw.TextStyle(lineSpacing: _lineSpacing),
          ),
        ],
      ),
    );
  }

  pw.Widget buildChartImage(String title, Uint8List chartBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Image(pw.MemoryImage(chartBytes), fit: pw.BoxFit.contain),
      ],
    );
  }

  pw.Widget buildDetailedDataSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    // Custom Table Border Style (Clean look: no vertical lines, thin horizontal lines)
    final pw.TableBorder tableBorder = pw.TableBorder(
      verticalInside: pw.BorderSide.none,
      horizontalInside: pw.BorderSide(width: 0.5, color: _pdf.PdfColors.grey400),
      top: pw.BorderSide(width: 0.5, color: _pdf.PdfColors.grey400),
      bottom: pw.BorderSide(width: 0.5, color: _pdf.PdfColors.grey400),
      left: pw.BorderSide.none,
      right: pw.BorderSide.none,
    );

    // Table Styling
    final pw.TextStyle headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
    const pw.TextStyle cellStyle = pw.TextStyle(fontSize: 10);
    const pw.EdgeInsets cellPadding = pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('DETAILED DATA', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),

        // --- Blood Sugar Records (Wrapped in pw.Column to keep title/table together) ---
        if (sugarRecords.isNotEmpty)
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Blood Sugar Records', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 10),

                pw.Table.fromTextArray(
                  border: tableBorder,
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                  cellPadding: cellPadding,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerDecoration: const pw.BoxDecoration(color: _pdf.PdfColors.grey100),
                  headers: ['Date', 'Time', 'Meal Time', 'Value', 'Status'],
                  data: sugarRecords.map((r) => [
                    DateFormat('MM-dd').format(r.date),
                    _formatTimeOfDay(r.time),
                    r.mealTimeCategory.toString().split('.').last,
                    r.value.toStringAsFixed(1),
                    r.status.toString().split('.').last,
                  ]).toList(),
                ),
                pw.SizedBox(height: 20),
              ]
          ),

        // --- Blood Pressure Records (Wrapped in pw.Column to keep title/table together) ---
        if (bpRecords.isNotEmpty)
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Blood Pressure Records', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 10),

                pw.Table.fromTextArray(
                  border: tableBorder,
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                  cellPadding: cellPadding,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerDecoration: const pw.BoxDecoration(color: _pdf.PdfColors.grey100),
                  headers: ['Date', 'Time', 'Time Name', 'Systolic', 'Diastolic', 'Pulse', 'Status'],
                  data: bpRecords.map((r) => [
                    DateFormat('MM-dd').format(r.date),
                    _formatTimeOfDay(r.time),
                    r.timeName.toString().split('.').last,
                    r.systolic.toString(),
                    r.diastolic.toString(),
                    r.pulseRate.toString(),
                    r.status.toString().split('.').last,
                  ]).toList(),
                ),
                pw.SizedBox(height: 20),
              ]
          ),

        if (bpRecords.isEmpty && sugarRecords.isEmpty)
          pw.Text('No detailed records available for the selected date range.'),
      ],
    );
  }


  // --- Helper Methods ---
  String _formatDate(DateTime date) => '${date.day}-${_shortMonth(date.month)}-${date.year}';
  String _formatDateTime(DateTime date) => '${date.day}-${_shortMonth(date.month)}-${date.year} ${date.hour}:${date.minute}';
  String _shortMonth(int month) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month-1];

  double _calculateBMI(UserProfile profile) {
    if (profile.measurementUnit == 'Metric') {
      return profile.weight / ((profile.height / 100) * (profile.height / 100));
    } else {
      return (profile.weight / (profile.height * profile.height)) * 703;
    }
  }

  T _min<T extends num>(List records, T Function(dynamic) selector) => records.map(selector).reduce(math.min);
  T _max<T extends num>(List records, T Function(dynamic) selector) => records.map(selector).reduce(math.max);
  double _avg(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    final sum = records.map(selector).reduce((a, b) => a + b);
    return (sum/records.length).toDouble();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }
}