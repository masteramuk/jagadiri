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

  //build charts for sugar, bp, pulse
  static Widget buildGlucoseChart(List<SugarRecord> records) {
    final spots = records.map((r) {
      final x = r.date.millisecondsSinceEpoch.toDouble();
      final y = r.value.toDouble();
      return FlSpot(x, y);
    }).toList();

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildGlucoseChart

  // Build charts for blood pressure (systolic and diastolic)
  static Widget buildBPChart(List<BPRecord> records) {
    final systolicSpots = records.map((r) {
      final x = r.date.millisecondsSinceEpoch.toDouble();
      final y = r.systolic.toDouble();
      return FlSpot(x, y);
    }).toList();

    final diastolicSpots = records.map((r) {
      final x = r.date.millisecondsSinceEpoch.toDouble();
      final y = r.diastolic.toDouble();
      return FlSpot(x, y);
    }).toList();

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: systolicSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: diastolicSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildBPChart

  // Build chart for pulse rate
  static Widget buildPulseChart(List<BPRecord> records) {
    final spots = records.map((r) {
      final x = r.date.millisecondsSinceEpoch.toDouble();
      final y = r.pulseRate.toDouble();
      return FlSpot(x, y);
    }).toList();

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  } //end buildPulseChart

  // Capture chart as image
  static Future<Uint8List> captureChartAsImage(GlobalKey chartKey) async {
    const maxRetries = 5;
    int attempts = 0;

    while (attempts < maxRetries) {
      final boundary = chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        print('attempt $attempts: boundary null');
      } else {
        bool needsPaint = false;
        if (kDebugMode) {
          needsPaint = boundary.debugNeedsPaint;
        }
        if (needsPaint) {
          print('attempt $attempts: boundary needs paint');
        } else {
          print('attempt $attempts: capturing image');
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData?.buffer.asUint8List();
          if (bytes != null) {
            print('capture done, bytes length: ${bytes.length}');
            return bytes;
          }
        }
      }
      attempts++;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    throw Exception('Failed to capture image after $maxRetries attempts');
  }

}