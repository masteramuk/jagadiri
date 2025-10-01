import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../services/database_service.dart';
import 'package:provider/provider.dart';

// Utility class to generate individual health trend charts
class IndividualHealthTrendChartGenerator {

  // --- Chart Building Methods ---

  // Utility to create a sequential list of FlSpot objects
  static List<FlSpot> _createSequentialSpots<T>(List<T> records, double Function(T) valueSelector) {
    return records.asMap().entries.map((e) {
      final x = e.key.toDouble(); // Sequential index 0, 1, 2, ...
      final y = valueSelector(e.value);
      return FlSpot(x, y);
    }).toList();
  }

  static Widget buildGlucoseChart(List<SugarRecord> records) {
    final spots = _createSequentialSpots(records, (r) => r.value.toDouble());

    return LineChart(
      LineChartData(
        // Set min/max X values based on the index count
        minX: 0,
        maxX: spots.isEmpty ? 0 : spots.length.toDouble() - 1,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildGlucoseChart

  // Build charts for blood pressure (systolic and diastolic)
  static Widget buildBPChart(List<BPRecord> records) {
    final systolicSpots = _createSequentialSpots(records, (r) => r.systolic.toDouble());
    final diastolicSpots = _createSequentialSpots(records, (r) => r.diastolic.toDouble());

    final maxX = records.isEmpty ? 0 : records.length.toDouble() - 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX as double,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: systolicSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: diastolicSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildBPChart

  // Build chart for pulse rate
  static Widget buildPulseChart(List<BPRecord> records) {
    final spots = _createSequentialSpots(records, (r) => r.pulseRate.toDouble());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.isEmpty ? 0 : spots.length.toDouble() - 1,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildPulseChart

  // --- IMAGE CAPTURE METHOD (No changes needed, this looks robust) ---

  // Capture chart as image
  static Future<Uint8List> captureChartAsImage(GlobalKey chartKey) async {
    const maxRetries = 5;
    int attempts = 0;

    while (attempts < maxRetries) {
      final boundary = chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        // print('attempt $attempts: boundary null'); // Keep console clean unless truly needed
      } else {
        bool needsPaint = false;
        if (kDebugMode) {
          needsPaint = boundary.debugNeedsPaint;
        }
        if (needsPaint) {
          // print('attempt $attempts: boundary needs paint');
        } else {
          // print('attempt $attempts: capturing image');
          // Add a very slight delay even after checking needsPaint for safety
          await Future.delayed(const Duration(milliseconds: 50));
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData?.buffer.asUint8List();
          if (bytes != null && bytes.isNotEmpty) { // Also check for empty bytes
            // print('capture done, bytes length: ${bytes.length}');
            return bytes;
          }
        }
      }
      attempts++;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // Return empty Uint8List instead of throwing an exception,
    // which allows the PDF generation to continue gracefully.
    debugPrint('Failed to capture image after $maxRetries attempts. Returning empty image.');
    return Uint8List(0);
  }

}
