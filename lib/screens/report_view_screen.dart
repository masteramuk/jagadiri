import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:jagadiri/utils/report_generator.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';

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
  String? _pdfPath;
  Uint8List? _excelBytes;

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
      setState(() {
        _pdfPath = pdfPath;
      });
    } else {
      final excelBytes = await reportGenerator.generateExcelReport(reportTypeEnum, startDate, endDate);
      setState(() {
        _excelBytes = excelBytes as Uint8List?;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveExcelFile() async {
    if (_excelBytes == null) return;

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: '${widget.reportType.replaceAll(' ', '_')}_Report.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: _excelBytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel report saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: ${e.toString()}')),
        );
      }
    }
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
          : _buildPreview(),
    );
  }

  Widget _buildPreview() {
    if (widget.format == 'PDF') {
      if (_pdfPath != null) {
        return PdfPreview(
          build: (format) => File(_pdfPath!).readAsBytes(),
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
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveExcelFile,
                icon: const Icon(Icons.download),
                label: const Text('Save Excel File'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
