import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as _pdf;
import 'package:pdf/widgets.dart' as pw;
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';
import 'health_analysis_service.dart';

class IndividualHealthTrendService {
  final HealthAnalysisService _analysisService = HealthAnalysisService();

  /// Generates PDF for Individual Health Trends report.
  Future<pw.Document> generatePdf({
    required List<SugarRecord> sugarReadings,
    required List<BPRecord> bpReadings,
    required UserProfile userProfile,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // ✅ Create document
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
            _buildHeader(userProfile, startDate, endDate),
            pw.SizedBox(height: 20),
            _buildSectionSeparator(),
            _buildSummarySection(userProfile, bpReadings, sugarReadings),
            pw.SizedBox(height: 20),
            _buildSectionSeparator(),
            _buildAnalysisSection(analysisText),
            pw.SizedBox(height: 20),
            _buildSectionSeparator(),
            //commenting out charts for now
            /*
            if (sugarReadings.isNotEmpty) _buildChartSection('Glucose Trend', chartDrawer.drawGlucoseChart(sugarReadings, 30)),
            if (bpReadings.isNotEmpty) _buildChartSection('Blood Pressure Trend', chartDrawer.drawBPChart(bpReadings, 30)),
            if (bpReadings.isNotEmpty) _buildChartSection('Pulse Rate Trend', chartDrawer.drawPulseChart(bpReadings, 30)),
            */
            pw.SizedBox(height: 20),
            _buildDetailedDataSection(bpReadings, sugarReadings),
          ];
        },
      ),
    );

    return pdf;
  }

  // ✅ IMPROVED: Cleaner, more professional header
  pw.Widget _buildHeader(UserProfile? userProfile, DateTime? startDate, DateTime? endDate) {
    String dateRangeText = '';
    if (startDate != null && endDate != null) {
      dateRangeText = 'Date Range: ${_formatDate(startDate)} - ${_formatDate(endDate)}';
    } else if (startDate != null) {
      dateRangeText = 'From: ${_formatDate(startDate)}';
    } else if (endDate != null) {
      dateRangeText = 'To: ${_formatDate(endDate)}';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _pdf.PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Health Report'),
          if (userProfile != null) ...[
            pw.Text('Name: ${userProfile.name}'),
            pw.Text('Date of Birth: ${userProfile.dob != null ? _formatDate(userProfile.dob!) : 'N/A'}'),
            pw.Text('Gender: ${userProfile.gender ?? 'N/A'}'),
            pw.Text('Height: ${userProfile.height.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'cm' : 'in'}'),
            pw.Text('Weight: ${userProfile.weight.toStringAsFixed(1)} ${userProfile.measurementUnit == 'Metric' ? 'kg' : 'lbs'}'),
            pw.Text('BMI: ${_calculateBMI(userProfile).toStringAsFixed(2)}'),
            pw.Text('Diabetic Status: ${userProfile.sugarScenario ?? 'N/A'}'),
          ],
          pw.Text('Report Date: ${_formatDateTime(DateTime.now())}'),
          if (dateRangeText.isNotEmpty) pw.Text(dateRangeText),
        ],
      ),
    );
  }

  // ✅ IMPROVED: Cleaner, more compact summary
  pw.Widget _buildSummarySection(UserProfile userProfile, List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _pdf.PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SUMMARY'),
          pw.SizedBox(height: 10),
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

  pw.Widget _buildAnalysisSection(String analysisText) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _pdf.PdfColors.green100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ENHANCED ANALYSIS'),
          pw.SizedBox(height: 10),
          pw.Paragraph(text: analysisText),
        ],
      ),
    );
  }

  // ✅ FIXED: Accepts pw.Widget directly — no more ChartDrawer
  pw.Widget _buildChartSection(String title, pw.Widget chartWidget) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdf.PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          chartWidget, // ✅ Just add the widget — no CanvasBuilder needed
        ],
      ),
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
          pw.Table(
            border: pw.TableBorder.all(color: _pdf.PdfColors.black),
            children: [
              // Table Headers
              pw.TableRow(
                children: [
                  pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Time Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Systolic', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Diastolic', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Pulse', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ].map((cell) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: cell)).toList(),
              ),
              // Table Data
              ...bpRecords.map((record) => pw.TableRow(
                children: [
                  pw.Text(DateFormat('dd-MMM-yyyy').format(record.date)),
                  pw.Text(_formatTimeOfDay(record.time)),
                  pw.Text(record.timeName.toString()),
                  pw.Text(record.systolic.toString()),
                  pw.Text(record.diastolic.toString()),
                  pw.Text(record.pulseRate.toString()),
                  pw.Text(record.status.toString()),
                ].map((text) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(text.toString()),
                )).toList(),
              )).toList(),
            ],
          ),
          pw.SizedBox(height: 20),
        ],
        if (sugarRecords.isNotEmpty) ...[
          pw.Text('Blood Sugar Records:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _pdf.PdfColors.black),
            children: [
              // Table Headers
              pw.TableRow(
                children: [
                  pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Meal Time Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Meal Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sugar Level', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ].map((cell) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: cell)).toList(),
              ),
              // Table Data
              ...sugarRecords.map((record) => pw.TableRow(
                children: [
                  pw.Text(DateFormat('dd-MMM-yyyy').format(record.date)),
                  pw.Text(_formatTimeOfDay(record.time)),
                  pw.Text(record.mealTimeCategory.toString()),
                  pw.Text(record.mealType.toString()),
                  pw.Text(record.value.toString()),
                  pw.Text(record.status.toString()),
                ].map((text) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(text.toString()),
                )).toList(),
              )).toList(),
            ],
          ),
        ],
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
  //double _avg<T extends num>(List records, T Function(dynamic) selector) => records.map(selector).reduce((a, b) => a + b) / records.length;
  double _avg(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    final sum = records.map(selector).reduce((a, b) => a + b);
    return (sum/records.length).toDouble();
  }

  pw.Widget _buildSectionSeparator() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: _pdf.PdfColors.grey300,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }
}