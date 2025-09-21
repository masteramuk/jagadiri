import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../services/individual_health_trend_service.dart';
import '../services/database_service.dart';

class ReportViewScreen extends StatefulWidget {
  final String reportId;
  final String reportLabel;
  final String reportDescription; // ✅ Added description
  final IconData? reportIcon; // Optional icon if needed

  const ReportViewScreen({
    super.key,
    required this.reportId,
    required this.reportLabel,
    required this.reportDescription, // ✅ Passed from ReportsScreen
    required this.reportIcon, // Optional
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 30));
    _endDate = now;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generatePDF() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final userProfile = await dbService.getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');

      final bpRecords = await dbService.getBPRecordsDateRange(startDate: _startDate, endDate: _endDate);
      final sugarRecords = await dbService.getSugarRecordsDateRange(startDate: _startDate, endDate: _endDate);

      Uint8List pdfBytes;

      switch (widget.reportId) {
        case 'individual_trends':
          final service = IndividualHealthTrendService();
          final pdf = await service.generatePdf(
            sugarReadings: sugarRecords,
            bpReadings: bpRecords,
            userProfile: userProfile,
            startDate: _startDate,
            endDate: _endDate,
          );
          pdfBytes = await pdf.save();
          break;
        default:
          throw UnimplementedError('PDF generation not implemented for ${widget.reportId}');
      }

      if (pdfBytes.isNotEmpty) {
        await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.reportLabel.replaceAll(' ', '_')}.pdf');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Generation'), // ✅ Static title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min, // Ensures the row only takes up as much space as its children
              children: [
                Icon(
                  widget.reportIcon ?? Icons.insert_drive_file,
                  size: 60,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
                const SizedBox(width: 16), // A bit of space between the icon and the text
                Text(
                  widget.reportLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select Date Range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDatePickerButton(context, 'Start Date', _startDate, true),
                _buildDatePickerButton(context, 'End Date', _endDate, false),
              ],
            ),
            const SizedBox(height: 24),

            // ✅ High-contrast note with icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[800]!, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Note: Selecting a date range of more than 3 months may cause the app to lag or slow.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87, // ✅ High contrast
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ✅ Generate Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    //Generate PDF for widget.reportId
                    _generatePDF();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF generation in process')),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Generate Excel for widget.reportId
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Excel generation not implemented yet.')),
                    );
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Generate Excel'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ✅ Report Description (carried from ReportsScreen)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About this report:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.reportDescription,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(
      BuildContext context, String label, DateTime date, bool isStartDate) {
    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}