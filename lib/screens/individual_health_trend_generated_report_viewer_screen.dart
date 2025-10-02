import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/services/health_analysis_service.dart';
import 'package:jagadiri/services/individual_health_trend_chart_generator.dart';
import 'package:jagadiri/services/individual_health_trend_service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import 'package:pdf/widgets.dart' as pw;

// Top-level function for PDF generation to be used with compute
Future<Uint8List> _generatePdfBytes(pw.Document pdf) async {
  return pdf.save();
}

// Top-level function for Excel generation to be used with compute
Future<List<int>> _generateExcelBytes(Map<String, dynamic> data) async {
  final List<SugarRecord> sugarRecords = data['sugar'];
  final List<BPRecord> bpRecords = data['bp'];
  final xlsio.Workbook workbook = xlsio.Workbook();
  if (sugarRecords.isNotEmpty) {
    final xlsio.Worksheet sugarSheet = workbook.worksheets[0];
    sugarSheet.name = 'Blood Sugar';
    sugarSheet.getRangeByName('A1').setText('Date');
    sugarSheet.getRangeByName('B1').setText('Time');
    sugarSheet.getRangeByName('C1').setText('Meal Time');
    sugarSheet.getRangeByName('D1').setText('Meal Type');
    sugarSheet.getRangeByName('E1').setText('Value (mg/dL)');
    sugarSheet.getRangeByName('F1').setText('Status');

    for (int i = 0; i < sugarRecords.length; i++) {
      final record = sugarRecords[i];
      sugarSheet
          .getRangeByIndex(i + 2, 1)
          .setText(DateFormat('yyyy-MM-dd').format(record.date));
      sugarSheet.getRangeByIndex(i + 2, 2).setText('${record.time.hour}:${record.time.minute}');
      sugarSheet
          .getRangeByIndex(i + 2, 3)
          .setText(record.mealTimeCategory.name);
      sugarSheet.getRangeByIndex(i + 2, 4).setText(record.mealType.name);
      sugarSheet
          .getRangeByIndex(i + 2, 5)
          .setNumber(record.value.toDouble());
      sugarSheet.getRangeByIndex(i + 2, 6).setText(record.status.name);
    }
  }

  if (bpRecords.isNotEmpty) {
    final xlsio.Worksheet bpSheet =
        workbook.worksheets.addWithName('Blood Pressure');
    bpSheet.getRangeByName('A1').setText('Date');
    bpSheet.getRangeByName('B1').setText('Time');
    bpSheet.getRangeByName('C1').setText('Time Name');
    bpSheet.getRangeByName('D1').setText('Systolic (mmHg)');
    bpSheet.getRangeByName('E1').setText('Diastolic (mmHg)');
    bpSheet.getRangeByName('F1').setText('Pulse (bpm)');
    bpSheet.getRangeByName('G1').setText('Status');

    for (int i = 0; i < bpRecords.length; i++) {
      final record = bpRecords[i];
      bpSheet
          .getRangeByIndex(i + 2, 1)
          .setText(DateFormat('yyyy-MM-dd').format(record.date));
      bpSheet.getRangeByIndex(i + 2, 2).setText('${record.time.hour}:${record.time.minute}');
      bpSheet.getRangeByIndex(i + 2, 3).setText(record.timeName.name);
      bpSheet
          .getRangeByIndex(i + 2, 4)
          .setNumber(record.systolic.toDouble());
      bpSheet
          .getRangeByIndex(i + 2, 5)
          .setNumber(record.diastolic.toDouble());
      bpSheet
          .getRangeByIndex(i + 2, 6)
          .setNumber(record.pulseRate.toDouble());
      bpSheet.getRangeByIndex(i + 2, 7).setText(record.status.name);
    }
  }

  final List<int> bytes = workbook.saveAsStream();
  workbook.dispose();
  return bytes;
}

class IndividualHealthTrendGeneratedReportViewerScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<SugarRecord> sugarRecords;
  final List<BPRecord> bpRecords;
  final DateTime startDate;
  final DateTime endDate;

  const IndividualHealthTrendGeneratedReportViewerScreen({
    super.key,
    required this.userProfile,
    required this.sugarRecords,
    required this.bpRecords,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<IndividualHealthTrendGeneratedReportViewerScreen> createState() =>
      _IndividualHealthTrendGeneratedReportViewerScreenState();
}

class _IndividualHealthTrendGeneratedReportViewerScreenState
    extends State<IndividualHealthTrendGeneratedReportViewerScreen> {
  late final String _analysisText;

  final _scrollController = ScrollController();
  final _summaryKey = GlobalKey();
  final _chartsKey = GlobalKey();
  final _sugarRecordsKey = GlobalKey();
  final _bpRecordsKey = GlobalKey();

  final _glucoseChartKey = GlobalKey();
  final _bpChartKey = GlobalKey();
  final _pulseChartKey = GlobalKey();

  Widget? _glucoseChart;
  Widget? _bpChart;
  Widget? _pulseChart;

  @override
  void initState() {
    super.initState();
    final analysisService = HealthAnalysisService();
    _analysisText = analysisService.generateAnalysisText(
      sugarReadings: widget.sugarRecords,
      bpReadings: widget.bpRecords,
      userProfile: widget.userProfile,
    );

    // Pre-build charts
    if (widget.sugarRecords.isNotEmpty) {
      _glucoseChart = RepaintBoundary(
        key: _glucoseChartKey,
        child: IndividualHealthTrendChartGenerator.buildGlucoseChart(
            widget.sugarRecords),
      );
    }
    if (widget.bpRecords.isNotEmpty) {
      _bpChart = RepaintBoundary(
        key: _bpChartKey,
        child:
        IndividualHealthTrendChartGenerator.buildBPChart(widget.bpRecords),
      );
      _pulseChart = RepaintBoundary(
        key: _pulseChartKey,
        child: IndividualHealthTrendChartGenerator.buildPulseChart(
            widget.bpRecords),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _savePdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );
    try {
      // Capture chart images
      final glucoseChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_glucoseChartKey);
      final bpChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_bpChartKey);
      final pulseChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_pulseChartKey);

      final service = IndividualHealthTrendService();
      final pdf = await service.generatePdf(
        sugarReadings: widget.sugarRecords,
        bpReadings: widget.bpRecords,
        userProfile: widget.userProfile,
        startDate: widget.startDate,
        endDate: widget.endDate,
        glucoseChartBytes: glucoseChartBytes,
        bpChartBytes: bpChartBytes,
        pulseChartBytes: pulseChartBytes,
      );

      final pdfBytes = await compute(_generatePdfBytes, pdf);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Health_Report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<void> _saveExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Excel file...')),
    );
    try {
      final List<int> bytes = await compute(_generateExcelBytes, {
        'sugar': widget.sugarRecords,
        'bp': widget.bpRecords,
      });

      final String path = (await getApplicationDocumentsDirectory()).path;
      final String fileName =
          '$path/HealthReport_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File(fileName);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate Excel file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Report'),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _savePdf,
              tooltip: 'Save as PDF'),
          IconButton(
              icon: const Icon(Icons.table_chart),
              onPressed: _saveExcel,
              tooltip: 'Save as Excel'),
        ],
      ),
      body: _buildReportContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return PopupMenuButton<int>(
      onSelected: _scrollToSection,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Summary')),
        const PopupMenuItem(value: 1, child: Text('Charts')),
        const PopupMenuItem(value: 2, child: Text('Sugar Records')),
        const PopupMenuItem(value: 3, child: Text('BP Records')),
      ],
      child: const FloatingActionButton(
        onPressed: null, // onPressed is handled by PopupMenuButton
        child: Icon(Icons.menu),
      ),
    );
  }

  void _scrollToSection(int index) {
    GlobalKey? key;
    switch (index) {
      case 0:
        key = _summaryKey;
        break;
      case 1:
        key = _chartsKey;
        break;
      case 2:
        key = _sugarRecordsKey;
        break;
      case 3:
        key = _bpRecordsKey;
        break;
    }

    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildReportContent() {
    final headerStyle = const TextStyle(fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: _summaryKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReportHeader(),
                const SizedBox(height: 16),
                _buildHeader(widget.userProfile, widget.startDate, widget.endDate),
                const SizedBox(height: 16),
                _buildSummary(widget.bpRecords, widget.sugarRecords),
                const SizedBox(height: 16),
                _buildAnalysis(_analysisText),
              ],
            ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _chartsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trend Analysis',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (_glucoseChart != null)
                  _buildSection(
                    'Glucose Trend',
                    SizedBox(height: 200, child: _glucoseChart),
                  ),
                const SizedBox(height: 24),
                if (_bpChart != null) ...[
                  _buildSection(
                    'Blood Pressure Trend',
                    SizedBox(height: 200, child: _bpChart),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_pulseChart != null) ...[
                  _buildSection(
                    'Pulse Trend',
                    SizedBox(height: 200, child: _pulseChart),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _sugarRecordsKey,
            child: _buildSection(
              'Blood Sugar Records',
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Date', style: headerStyle)),
                    DataColumn(label: Text('Time', style: headerStyle)),
                    DataColumn(label: Text('Meal Time', style: headerStyle)),
                    DataColumn(label: Text('Value', style: headerStyle)),
                    DataColumn(label: Text('Status', style: headerStyle)),
                  ],
                  rows: widget.sugarRecords
                      .map((r) => DataRow(cells: [
                    DataCell(Text(DateFormat('MM-dd').format(r.date))),
                    DataCell(Text(r.time.format(context))),
                    DataCell(Text(r.mealTimeCategory.name)),
                    DataCell(Text(r.value.toStringAsFixed(1))),
                    DataCell(Text(r.status.name)),
                  ]))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _bpRecordsKey,
            child: _buildSection(
              'Blood Pressure & Pulse Records',
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Date', style: headerStyle)),
                    DataColumn(label: Text('Time', style: headerStyle)),
                    DataColumn(label: Text('Systolic', style: headerStyle)),
                    DataColumn(label: Text('Diastolic', style: headerStyle)),
                    DataColumn(label: Text('Pulse', style: headerStyle)),
                    DataColumn(label: Text('Status', style: headerStyle)),
                  ],
                  rows: widget.bpRecords
                      .map((r) => DataRow(cells: [
                    DataCell(Text(DateFormat('MM-dd').format(r.date))),
                    DataCell(Text(r.time.format(context))),
                    DataCell(Text(r.systolic.toString())),
                    DataCell(Text(r.diastolic.toString())),
                    DataCell(Text(r.pulseRate.toString())),
                    DataCell(Text(r.status.name)),
                  ]))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader() {
    return Column(
      children: [
        Icon(Icons.health_and_safety, size: 80, color: Theme.of(context).primaryColor),
        const SizedBox(height: 16),
        Text(
          'Individual Health Trend Analysis Report',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Report Generated on ${DateFormat.yMMMd().format(DateTime.now())}',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildHeader(
      UserProfile profile, DateTime startDate, DateTime endDate) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Health Report',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Text('Name: ${profile.name}'),
                  Text(
                      'Date of Birth: ${profile.dob != null ? DateFormat.yMMMd().format(profile.dob!) : 'N/A'}'),
                  Text('Diabetic Status: ${profile.sugarScenario ?? 'N/A'}'),
                  const Divider(height: 20),
                  Text('Report Date: ${DateFormat.yMMMd().format(DateTime.now())}'),
                  Text(
                      'Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
      List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.article, size: 40, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  if (sugarRecords.isNotEmpty)
                    Text(
                        'Avg Glucose: ${_avg(sugarRecords, (r) => r.value).toStringAsFixed(1)} mg/dL'),
                  if (bpRecords.isNotEmpty) ...[
                    Text(
                        'Avg BP: ${_avg(bpRecords, (r) => r.systolic).round()}/${_avg(bpRecords, (r) => r.diastolic).round()} mmHg'),
                    Text(
                        'Avg Pulse: ${_avg(bpRecords, (r) => r.pulseRate).round()} bpm'),
                  ],
                  if (sugarRecords.isEmpty && bpRecords.isEmpty)
                    const Text('No data available for this period.')
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysis(String analysisText) {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.analytics, size: 40, color: Colors.blue.shade800),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health Analysis',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                  const Divider(height: 20),
                  Text(analysisText, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _avg(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a + b) / records.length;
  }
}
