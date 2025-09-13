
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:jagadiri/utils/report_generator.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

class ReportViewScreen extends StatefulWidget {
  final String reportType;
  final String format;

  const ReportViewScreen({
    super.key,
    required this.reportType,
    required this.format,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  bool _isLoading = true;
  String? _reportPath;
  Widget? _previewWidget;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
    });

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final reportGenerator = ReportGenerator(dbService: dbService);

    final reportTypeEnum = _getReportTypeEnum(widget.reportType);
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    if (widget.format == 'PDF') {
      final pdfPath = await reportGenerator.generatePdfReport(reportTypeEnum, startDate, endDate);
      if (pdfPath != null) {
        final file = File(pdfPath);
        final pdfPreview = await Printing.layoutPdf(
            onLayout: (format) => file.readAsBytes());
        setState(() {
          _reportPath = pdfPath;
          _previewWidget = const Text('PDF Preview Loaded'); // Placeholder, actual preview is handled by Printing package
        });
      } else {
        // Handle error
      }
    } else {
      final excelPath = await reportGenerator.generateExcelReport(reportTypeEnum, startDate, endDate);
       if (excelPath != null) {
        setState(() {
          _reportPath = excelPath;
        });
      } else {
        // Handle error
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  ReportType _getReportTypeEnum(String reportType) {
    switch (reportType) {
      case 'Individual Health Trends':
        return ReportType.individualTrends;
      case 'Comparison and Summary':
        return ReportType.comparisonSummary;
      case 'Risk Assessment':
        return ReportType.riskAssessment;
      case 'Correlation':
        return ReportType.correlation;
      case 'Body Composition & Goal Tracking':
        return ReportType.bodyComposition;
      default:
        return ReportType.individualTrends;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View ${widget.reportType}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _buildPreview(),
                ),
                _buildDownloadButtons(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildPreview() {
    if (widget.format == 'PDF') {
      if (_reportPath != null) {
        return PdfPreview(
          build: (format) => File(_reportPath!).readAsBytes(),
        );
      } else {
        return const Center(child: Text('Could not load PDF preview.'));
      }
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 10),
              const Text(
                'Excel Report Generated Successfully!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text('Saved to: $_reportPath'),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDownloadButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.format == 'PDF')
          ElevatedButton.icon(
            onPressed: () async {
              if (_reportPath != null) {
                final file = File(_reportPath!);
                await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'report.pdf');
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
          ),
        if (widget.format == 'Excel')
          ElevatedButton.icon(
            onPressed: () {
              if (_reportPath != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Excel file saved at: $_reportPath')),
                );
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Show Path'),
          ),
      ],
    );
  }
}
