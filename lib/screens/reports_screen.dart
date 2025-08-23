import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _generatePdfReport(BuildContext context) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final sugarRecords = await databaseService.getSugarRecords();
    final bpRecords = await databaseService.getBPRecords();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pwContext) => [
          pw.Center(
            child: pw.Text('JagaDiri Health Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Sugar Records', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Time', 'Category', 'Type', 'Value', 'Status'],
            data: sugarRecords.map((record) => [
              record.date.toLocal().toString().split(' ')[0],
              record.time.format(context),
              record.mealTimeCategory.name.toUpperCase(),
              record.mealType.name.split(RegExp(r'(?=[A-Z])')).join(' ').toUpperCase(),
              record.value.toStringAsFixed(1),
              record.status.name.toUpperCase(),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text('BP Records', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Time', 'TOD', 'Sys', 'Dia', 'Pulse', 'Status'],
            data: bpRecords.map((record) => [
              record.date.toLocal().toString().split(' ')[0],
              record.time.format(context),
              record.timeName.name.toUpperCase(),
              record.systolic.toString(),
              record.diastolic.toString(),
              record.pulseRate.toString(),
              record.status.name.toUpperCase(),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _generateExcelReport(BuildContext context) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final sugarRecords = await databaseService.getSugarRecords();
    final bpRecords = await databaseService.getBPRecords();

    final excel = Excel.createExcel();

    // Sugar Data Sheet
    Sheet sugarSheet = excel['Sugar Data'];
    sugarSheet.appendRow(['Date', 'Time', 'Meal Time Category', 'Meal Type', 'Value', 'Status']);
    for (var record in sugarRecords) {
      sugarSheet.appendRow([
        record.date.toLocal().toString().split(' ')[0],
        record.time.format(context),
        record.mealTimeCategory.name.toUpperCase(),
        record.mealType.name.split(RegExp(r'(?=[A-Z])')).join(' ').toUpperCase(),
        record.value,
        record.status.name.toUpperCase(),
      ]);
    }

    // BP Data Sheet
    Sheet bpSheet = excel['BP Data'];
    bpSheet.appendRow(['Date', 'Time', 'Time of Day', 'Systolic', 'Diastolic', 'Pulse Rate', 'Status']);
    for (var record in bpRecords) {
      bpSheet.appendRow([
        record.date.toLocal().toString().split(' ')[0],
        record.time.format(context),
        record.timeName.name.toUpperCase(),
        record.systolic,
        record.diastolic,
        record.pulseRate,
        record.status.name.toUpperCase(),
      ]);
    }

    // Save the Excel file
    final directory = await getApplicationDocumentsDirectory();
    final path = '\${directory.path}/JagaDiri_Health_Report.xlsx';
    final file = File(path);
    await file.writeAsBytes(excel.encode()!); // Use encode()! to get bytes

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel report saved to: \$path')),
    );

    print('Excel report saved to: \$path');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _generatePdfReport(context),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _generateExcelReport(context),
              icon: const Icon(Icons.table_chart),
              label: const Text('Generate Excel Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}