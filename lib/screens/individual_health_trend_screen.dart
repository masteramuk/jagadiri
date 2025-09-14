import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../services/database_service.dart';
import '../services/ind_health_trend_report_generator_service.dart';
import '../providers/user_profile_provider.dart';

class IndividualHealthTrendScreen extends StatefulWidget {
  const IndividualHealthTrendScreen({super.key});

  @override
  State<IndividualHealthTrendScreen> createState() =>
      _IndividualHealthTrendScreenState();
}

class _IndividualHealthTrendScreenState
    extends State<IndividualHealthTrendScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Individual Health Trends'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              'Note: Selecting a date range of more than 3 months may cause the app to lag.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row( // Buttons Row
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final databaseService = Provider.of<DatabaseService>(context, listen: false);
                      final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
                      final indHealthTrendReportGeneratorService = IndHealthTrendReportGeneratorService(databaseService, userProfileProvider);

                      final pdfBytes = await indHealthTrendReportGeneratorService.generateReport(
                        startDate: _startDate,
                        endDate: _endDate,
                      );

                      if (pdfBytes.isNotEmpty) {
                        await Printing.sharePdf(bytes: pdfBytes, filename: 'health_trend_report.pdf');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PDF generation resulted in empty content.')),
                        );
                      }
                    } catch (e, stackTrace) {
                      print('Error generating PDF from IndividualHealthTrendScreen: $e');
                      print('Stack trace: $stackTrace');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating PDF: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement Excel generation
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Generate Excel'),
                ),
              ], // End of Row children
            ), // End of Buttons Row
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}