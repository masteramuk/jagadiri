import 'dart:io';
import 'dart:typed_data';
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

  final _reportContentKey = GlobalKey(); //to be use for printing purpose

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

  Future<void> _printReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing for printing...')),
    );
    try {
      final service = IndividualHealthTrendService();
      final glucoseChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_glucoseChartKey);
      final bpChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_bpChartKey);
      final pulseChartBytes = await IndividualHealthTrendChartGenerator.captureChartAsImage(_pulseChartKey);

      final pdfBytes = await service.generatePrintablePdf(
        sugarReadings: widget.sugarRecords,
        bpReadings: widget.bpRecords,
        userProfile: widget.userProfile,
        startDate: widget.startDate,
        endDate: widget.endDate,
        glucoseChartBytes: glucoseChartBytes,
        bpChartBytes: bpChartBytes,
        pulseChartBytes: pulseChartBytes,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to prepare for printing: $e')),
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
              icon: const Icon(Icons.print),
              onPressed: _printReport,
              tooltip: 'Print Report'),
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
      // Wrap the content in RepaintBoundary
      child: RepaintBoundary(
        key: _reportContentKey, // <-- using the key for printing alignment
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReportHeader(),
            _coloredDivider(color: Colors.blue, thickness: 2.0),
            _buildHeader(widget.userProfile, widget.startDate, widget.endDate),
            _coloredDivider(color: Colors.green, thickness: 2.0),
            _buildSummary(widget.bpRecords, widget.sugarRecords),
            _coloredDivider(color: Colors.orange, thickness: 2.0),
            _buildAnalysis(_analysisText),
            _coloredDivider(color: Colors.purple, thickness: 2.0),
            KeyedSubtree(
              key: _chartsKey,
              child: _buildSection(
                'Trend Analysis',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_glucoseChart != null)
                      Column(
                        children: [
                          Text('Glucose Trend', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(height: 200, child: _glucoseChart),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (_bpChart != null)
                      Column(
                        children: [
                          Text('Blood Pressure Trend', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(height: 200, child: _bpChart),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (_pulseChart != null)
                      Column(
                        children: [
                          Text('Pulse Trend', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(height: 200, child: _pulseChart),
                          const SizedBox(height: 16),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            _coloredDivider(color: Colors.red, thickness: 2.0),
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
            _coloredDivider(color: Colors.teal, thickness: 2.0),
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        child,
      ],
    );
  }

  Widget _buildHeader(
      UserProfile profile, DateTime startDate, DateTime endDate) {
    final String weightUnit = profile.measurementUnit == 'Metric' ? 'kg' : 'lbs';
    final String heightUnit = profile.measurementUnit == 'Metric' ? 'cm' : 'inches';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Icon(Icons.person_2_outlined, size: 40, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Text('Name: ${profile.name}'),
                Text(
                    'Date of Birth: ${profile.dob != null ? DateFormat.yMMMd().format(profile.dob!) : 'N/A'}'),
                Text('Gender: ${profile.gender ?? 'N/A'}'),
                Text('Diabetic Status: ${profile.sugarScenario ?? 'N/A'}'),
                const Divider(height: 20),
                Text('Height: ${profile.height.toStringAsFixed(1)} $heightUnit'),
                Text('Weight: ${profile.weight.toStringAsFixed(1)} $weightUnit'),
                Text('Target Weight: ${profile.targetWeight.toStringAsFixed(1)} $weightUnit'),
                Text('BMI: ${profile.bmi.toStringAsFixed(1)}'),
                const Divider(height: 20),
                Text('Suitable Sugar: ${profile.suitableSugarMin?.toStringAsFixed(0) ?? 'N/A'} - ${profile.suitableSugarMax?.toStringAsFixed(0) ?? 'N/A'} mg/dL'),
                Text('Suitable BP: ${profile.suitableSystolicMin?.toString() ?? 'N/A'}/${profile.suitableDiastolicMin?.toString() ?? 'N/A'} - ${profile.suitableSystolicMax?.toString() ?? 'N/A'}/${profile.suitableDiastolicMax?.toString() ?? 'N/A'} mmHg'),
                Text('Suitable Pulse: ${profile.suitablePulseMin?.toString() ?? 'N/A'} - ${profile.suitablePulseMax?.toString() ?? 'N/A'} bpm'),
                const Divider(height: 20),
                Text(
                    'Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}'),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildMeasurementBox(String title, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('$value $unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _getSugarStatusColor(double value) {
    if (widget.userProfile.suitableSugarMin == null || widget.userProfile.suitableSugarMax == null) {
      return Colors.grey;
    }
    if (value >= widget.userProfile.suitableSugarMin! && value <= widget.userProfile.suitableSugarMax!) {
      return Colors.green;
    } else if (value < widget.userProfile.suitableSugarMin! * 0.8 || value > widget.userProfile.suitableSugarMax! * 1.2) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  Color _getBpStatusColor(double systolic, double diastolic) {
    if (widget.userProfile.suitableSystolicMin == null || widget.userProfile.suitableSystolicMax == null ||
        widget.userProfile.suitableDiastolicMin == null || widget.userProfile.suitableDiastolicMax == null) {
      return Colors.grey;
    }
    if (systolic >= widget.userProfile.suitableSystolicMin! && systolic <= widget.userProfile.suitableSystolicMax! &&
        diastolic >= widget.userProfile.suitableDiastolicMin! && diastolic <= widget.userProfile.suitableDiastolicMax!) {
      return Colors.green;
    } else if (systolic < widget.userProfile.suitableSystolicMin! * 0.8 || systolic > widget.userProfile.suitableSystolicMax! * 1.2 ||
               diastolic < widget.userProfile.suitableDiastolicMin! * 0.8 || diastolic > widget.userProfile.suitableDiastolicMax! * 1.2) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  Color _getPulseStatusColor(double value) {
    if (widget.userProfile.suitablePulseMin == null || widget.userProfile.suitablePulseMax == null) {
      return Colors.grey;
    }
    if (value >= widget.userProfile.suitablePulseMin! && value <= widget.userProfile.suitablePulseMax!) {
      return Colors.green;
    } else if (value < widget.userProfile.suitablePulseMin! * 0.8 || value > widget.userProfile.suitablePulseMax! * 1.2) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  Widget _buildSummary(
      List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    final double avgGlucose = _avg(sugarRecords, (r) => r.value);
    final double minGlucose = _min(sugarRecords, (r) => r.value);
    final double maxGlucose = _max(sugarRecords, (r) => r.value);

    final double avgSystolic = _avg(bpRecords, (r) => r.systolic);
    final double minSystolic = _min(bpRecords, (r) => r.systolic);
    final double maxSystolic = _max(bpRecords, (r) => r.systolic);

    final double avgDiastolic = _avg(bpRecords, (r) => r.diastolic);
    final double minDiastolic = _min(bpRecords, (r) => r.diastolic);
    final double maxDiastolic = _max(bpRecords, (r) => r.diastolic);

    final double avgPulse = _avg(bpRecords, (r) => r.pulseRate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article, size: 40, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 16),
            const Text('Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const Divider(height: 20),
        if (sugarRecords.isEmpty && bpRecords.isEmpty)
          const Text('No data available for this period.')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Glucose Summary
              const Text('Glucose (mg/dL)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMeasurementBox('Min', minGlucose.toStringAsFixed(1), 'mg/dL', _getSugarStatusColor(minGlucose)),
                  _buildMeasurementBox('Max', maxGlucose.toStringAsFixed(1), 'mg/dL', _getSugarStatusColor(maxGlucose)),
                  _buildMeasurementBox('Avg', avgGlucose.toStringAsFixed(1), 'mg/dL', _getSugarStatusColor(avgGlucose)),
                ],
              ),
              const SizedBox(height: 16),

              // Blood Pressure Summary
              const Text('Blood Pressure (mmHg)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMeasurementBox('Min', '${minSystolic.round()}/${minDiastolic.round()}', 'mmHg', _getBpStatusColor(minSystolic, minDiastolic)),
                  _buildMeasurementBox('Max', '${maxSystolic.round()}/${maxDiastolic.round()}', 'mmHg', _getBpStatusColor(maxSystolic, maxDiastolic)),
                  _buildMeasurementBox('Avg', '${avgSystolic.round()}/${avgDiastolic.round()}', 'mmHg', _getBpStatusColor(avgSystolic, avgDiastolic)),
                ],
              ),
              const SizedBox(height: 16),

              // Pulse Summary
              const Text('Pulse (bpm)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMeasurementBox(
                    'Avg',
                    avgPulse.round().toString(),
                    'bpm',
                    _getPulseStatusColor(avgPulse),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAnalysis(String analysisText) {
    return Row(
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
    );
  }

  Widget _coloredDivider({Color color = Colors.grey, double thickness = 1.0, double height = 24.0}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: height / 2 - thickness / 2),
      height: thickness,
      color: color,
    );
  }

  double _avg(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a + b) / records.length;
  }

  double _min(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a < b ? a : b).toDouble();
  }

  double _max(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a > b ? a : b).toDouble();
  }
}