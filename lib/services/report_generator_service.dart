import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import '../providers/user_profile_provider.dart';

class ReportGeneratorService {
  final DatabaseService _databaseService;
  final UserProfileProvider _userProfileProvider;

  ReportGeneratorService(this._databaseService, this._userProfileProvider);

  Future<Uint8List> generateReport({DateTime? startDate, DateTime? endDate}) async {
    final pdf = pw.Document();

    try {
      final UserProfile? userProfile = _userProfileProvider.userProfile;
      final List<BPRecord> bpRecords = await _databaseService.getBPRecordsDateRange(startDate: startDate, endDate: endDate);
      final List<SugarRecord> sugarRecords = await _databaseService.getSugarRecordsDateRange(startDate: startDate, endDate: endDate);

      // Load a font that supports a wider range of characters, if necessary
      // final font = await PdfGoogleFonts.openSansRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(userProfile),
              pw.SizedBox(height: 20),
              _buildSummarySection(bpRecords, sugarRecords),
              pw.SizedBox(height: 20),
              _buildAnalysisSection(bpRecords, sugarRecords),
              pw.SizedBox(height: 20),
              _buildDetailedDataSection(bpRecords, sugarRecords),
            ];
          },
        ),
      );

      return pdf.save();
    } catch (e, stackTrace) {
      print('Error generating PDF: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw the error so it can be caught by the caller (reports_screen.dart)
    }
  }

  pw.Widget _buildHeader(UserProfile? userProfile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Health Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if (userProfile != null) ...[
          pw.Text('Name: ${userProfile.name}', style: pw.TextStyle(fontSize: 18)),
          //pw.Text('Date of Birth: ${userProfile.dateOfBirth?.toLocal().toString().split(' ')[0] ?? 'N/A'}', style: pw.TextStyle(fontSize: 18)),
          // Use `?.` to safely access userProfile first, then `dateOfBirth`.
          pw.Text('Date of Birth: ${userProfile?.dob?.toLocal().toString().split(' ')[0] ?? 'N/A'}', style: pw.TextStyle(fontSize: 18)),

          pw.Text('Gender: ${userProfile.gender ?? 'N/A'}', style: pw.TextStyle(fontSize: 18)),
        ],
        pw.Text('Report Date: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: pw.TextStyle(fontSize: 18)),
      ],
    );
  }

  pw.Widget _buildSummarySection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    // Implement summary logic here
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('Total BP Records: ${bpRecords.length}'),
        pw.Text('Total Sugar Records: ${sugarRecords.length}'),
        // Add more summary details like averages, min/max, etc.
      ],
    );
  }

  pw.Widget _buildAnalysisSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    // Implement analysis logic here
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Analysis', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('BP Analysis: ...'),
        pw.Text('Sugar Analysis: ...'),
        // Add more detailed analysis based on health data
      ],
    );
  }

  pw.Widget _buildDetailedDataSection(List<BPRecord> bpRecords, List<SugarRecord> sugarRecords) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Detailed Data', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Blood Pressure Records:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Date', 'Systolic', 'Diastolic', 'Pulse'],
          data: bpRecords.map((record) => [
            record.date.toLocal().toString().split(' ')[0],
            record.systolic.toString(),
            record.diastolic.toString(),
            record.pulseRate.toString(),
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Blood Sugar Records:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Date', 'Sugar Level', 'Notes'],
          data: sugarRecords.map((record) => [
            record.date.toLocal().toString().split(' ')[0],
            record.value.toString(),
            record.notes ?? '',
          ]).toList(),
        ),
      ],
    );
  }
}