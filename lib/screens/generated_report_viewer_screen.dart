import 'dart:io';
import 'dart:typed_data';
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
import 'dart:math' as math;

class GeneratedReportViewerScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<SugarRecord> sugarRecords;
  final List<BPRecord> bpRecords;
  final DateTime startDate;
  final DateTime endDate;

  const GeneratedReportViewerScreen({
    super.key,
    required this.userProfile,
    required this.sugarRecords,
    required this.bpRecords,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<GeneratedReportViewerScreen> createState() => _GeneratedReportViewerScreenState();
}

class _GeneratedReportViewerScreenState extends State<GeneratedReportViewerScreen> {
  late final String _analysisText;
  late final PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    final analysisService = HealthAnalysisService();
    _analysisText = analysisService.generateAnalysisText(
      sugarReadings: widget.sugarRecords,
      bpReadings: widget.bpRecords,
      userProfile: widget.userProfile,
    );
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _currentPageIndex = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _savePdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );
    try {
      final service = IndividualHealthTrendService();
      final pdf = await service.generatePdf(
        sugarReadings: widget.sugarRecords,
        bpReadings: widget.bpRecords,
        userProfile: widget.userProfile,
        startDate: widget.startDate,
        endDate: widget.endDate,
        glucoseChartBytes: Uint8List(0),
        bpChartBytes: Uint8List(0),
        pulseChartBytes: Uint8List(0),
      );

      final pdfBytes = await pdf.save();
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
      final xlsio.Workbook workbook = xlsio.Workbook();
      if (widget.sugarRecords.isNotEmpty) {
        final xlsio.Worksheet sugarSheet = workbook.worksheets[0];
        sugarSheet.name = 'Blood Sugar';
        sugarSheet.getRangeByName('A1').setText('Date');
        sugarSheet.getRangeByName('B1').setText('Time');
        sugarSheet.getRangeByName('C1').setText('Meal Time');
        sugarSheet.getRangeByName('D1').setText('Meal Type');
        sugarSheet.getRangeByName('E1').setText('Value (mg/dL)');
        sugarSheet.getRangeByName('F1').setText('Status');

        for (int i = 0; i < widget.sugarRecords.length; i++) {
          final record = widget.sugarRecords[i];
          sugarSheet.getRangeByIndex(i + 2, 1).setText(DateFormat('yyyy-MM-dd').format(record.date));
          sugarSheet.getRangeByIndex(i + 2, 2).setText(record.time.format(context));
          sugarSheet.getRangeByIndex(i + 2, 3).setText(record.mealTimeCategory.name);
          sugarSheet.getRangeByIndex(i + 2, 4).setText(record.mealType.name);
          sugarSheet.getRangeByIndex(i + 2, 5).setNumber(record.value.toDouble());
          sugarSheet.getRangeByIndex(i + 2, 6).setText(record.status.name);
        }
      }

      if (widget.bpRecords.isNotEmpty) {
        final xlsio.Worksheet bpSheet = workbook.worksheets.addWithName('Blood Pressure');
        bpSheet.getRangeByName('A1').setText('Date');
        bpSheet.getRangeByName('B1').setText('Time');
        bpSheet.getRangeByName('C1').setText('Time Name');
        bpSheet.getRangeByName('D1').setText('Systolic (mmHg)');
        bpSheet.getRangeByName('E1').setText('Diastolic (mmHg)');
        bpSheet.getRangeByName('F1').setText('Pulse (bpm)');
        bpSheet.getRangeByName('G1').setText('Status');

        for (int i = 0; i < widget.bpRecords.length; i++) {
          final record = widget.bpRecords[i];
          bpSheet.getRangeByIndex(i + 2, 1).setText(DateFormat('yyyy-MM-dd').format(record.date));
          bpSheet.getRangeByIndex(i + 2, 2).setText(record.time.format(context));
          bpSheet.getRangeByIndex(i + 2, 3).setText(record.timeName.name);
          bpSheet.getRangeByIndex(i + 2, 4).setNumber(record.systolic.toDouble());
          bpSheet.getRangeByIndex(i + 2, 5).setNumber(record.diastolic.toDouble());
          bpSheet.getRangeByIndex(i + 2, 6).setNumber(record.pulseRate.toDouble());
          bpSheet.getRangeByIndex(i + 2, 7).setText(record.status.name);
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final String path = (await getApplicationDocumentsDirectory()).path;
      final String fileName = '$path/HealthReport_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _savePdf, tooltip: 'Save as PDF'),
          IconButton(icon: const Icon(Icons.table_chart), onPressed: _saveExcel, tooltip: 'Save as Excel'),
        ],
      ),
      body: Column(
        children: [
          _buildPageNavigator(),
          const Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                _buildPageOne(),
                _buildPageTwo(),
                _buildPageThree(),
                _buildPageFour(),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildPageNavigator(),
        ],
      ),
    );
  }

  Widget _buildPageNavigator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          final isSelected = _currentPageIndex == index;
          return isSelected
              ? ElevatedButton(
                  onPressed: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  child: Text('Page ${index + 1}'),
                )
              : OutlinedButton(
                  onPressed: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  child: Text('Page ${index + 1}'),
                );
        }),
      ),
    );
  }

  Widget _buildPageOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(widget.userProfile, widget.startDate, widget.endDate),
          const SizedBox(height: 16),
          _buildSummary(widget.bpRecords, widget.sugarRecords),
          const SizedBox(height: 16),
          _buildAnalysis(_analysisText),
        ],
      ),
    );
  }

  Widget _buildPageTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trend Analysis', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (widget.sugarRecords.isNotEmpty)
            _buildSection(
              'Glucose Trend',
              SizedBox(height: 200, child: IndividualHealthTrendChartGenerator.buildGlucoseChart(widget.sugarRecords)),
            ),
          const SizedBox(height: 24),
          if (widget.bpRecords.isNotEmpty) ...[
            _buildSection(
              'Blood Pressure Trend',
              SizedBox(height: 200, child: IndividualHealthTrendChartGenerator.buildBPChart(widget.bpRecords)),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Pulse Trend',
              SizedBox(height: 200, child: IndividualHealthTrendChartGenerator.buildPulseChart(widget.bpRecords)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageThree() {
    final headerStyle = const TextStyle(fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
            rows: widget.sugarRecords.map((r) => DataRow(cells: [
              DataCell(Text(DateFormat('MM-dd').format(r.date))),
              DataCell(Text(r.time.format(context))),
              DataCell(Text(r.mealTimeCategory.name)),
              DataCell(Text(r.value.toStringAsFixed(1))),
              DataCell(Text(r.status.name)),
            ])).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPageFour() {
    final headerStyle = const TextStyle(fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
            rows: widget.bpRecords.map((r) => DataRow(cells: [
              DataCell(Text(DateFormat('MM-dd').format(r.date))),
              DataCell(Text(r.time.format(context))),
              DataCell(Text(r.systolic.toString())),
              DataCell(Text(r.diastolic.toString())),
              DataCell(Text(r.pulseRate.toString())),
              DataCell(Text(r.status.name)),
            ])).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildHeader(UserProfile profile, DateTime startDate, DateTime endDate) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Health Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text('Name: ${profile.name}'),
            Text('Date of Birth: ${profile.dob != null ? DateFormat.yMMMd().format(profile.dob!) : 'N/A'}'),
            Text('Diabetic Status: ${profile.sugarScenario ?? 'N/A'}'),
            const Divider(height: 20),
            Text('Report Date: ${DateFormat.yMMMd().format(DateTime.now())}'),
            Text('Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            if (sugarRecords.isNotEmpty)
              Text('Avg Glucose: ${_avg(sugarRecords, (r) => r.value).toStringAsFixed(1)} mg/dL'),
            if (bpRecords.isNotEmpty) ...[
              Text('Avg BP: ${_avg(bpRecords, (r) => r.systolic).round()}/${_avg(bpRecords, (r) => r.diastolic).round()} mmHg'),
              Text('Avg Pulse: ${_avg(bpRecords, (r) => r.pulseRate).round()} bpm'),
            ],
            if (sugarRecords.isEmpty && bpRecords.isEmpty)
              const Text('No data available for this period.')
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            const Divider(height: 20),
            Text(analysisText, style: const TextStyle(height: 1.5)),
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