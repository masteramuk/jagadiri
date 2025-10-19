import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // Import for max() function

// Utility class to generate individual health trend charts
class IndividualHealthTrendChartGenerator {

  // --- Data Preprocessing Utilities ---

  // Converts a list of records (which might contain multiple entries per day)
  // into a list of simplified data points (date and averaged value)
  static List<Map<String, dynamic>> _processRecordsByDate<T>(
      List<T> records,
      String Function(T) dateSelector, // Function to get a unique date string (YYYY-MM-DD)
      double Function(T) valueSelector // Function to get the value for averaging
      ) {
    if (records.isEmpty) return [];

    // 1. Group records by date (YYYY-MM-DD)
    final Map<String, List<T>> grouped = {};
    for (var record in records) {
      final dateKey = dateSelector(record);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(record);
    }

    // Sort the dates to ensure the chart order is correct
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateFormat('yyyy-MM-dd').parse(a).compareTo(DateFormat('yyyy-MM-dd').parse(b)));

    // 2. Calculate the average value for each day
    final List<Map<String, dynamic>> processedData = [];
    for (var dateKey in sortedKeys) {
      final dailyRecords = grouped[dateKey]!;
      // Calculate average value
      final totalValue = dailyRecords.fold<double>(0.0, (sum, record) => sum + valueSelector(record));
      final avgValue = totalValue / dailyRecords.length;

      // For BP, we need to handle systolic and diastolic separately if T == BPRecord
      if (T == BPRecord) {
        final totalSystolic = dailyRecords.fold<double>(0.0, (sum, record) => sum + (record as BPRecord).systolic.toDouble());
        final totalDiastolic = dailyRecords.fold<double>(0.0, (sum, record) => sum + (record as BPRecord).diastolic.toDouble());
        final totalPulse = dailyRecords.fold<double>(0.0, (sum, record) => sum + (record as BPRecord).pulseRate.toDouble());

        processedData.add({
          'date': DateFormat('yyyy-MM-dd').parse(dateKey),
          'systolic_avg': totalSystolic / dailyRecords.length,
          'diastolic_avg': totalDiastolic / dailyRecords.length,
          'pulse_avg': totalPulse / dailyRecords.length,
        });
      } else {
        processedData.add({
          'date': DateFormat('yyyy-MM-dd').parse(dateKey),
          'value_avg': avgValue,
        });
      }
    }

    return processedData;
  }

  // Utility to create a sequential list of FlSpot objects from processed data
  static List<FlSpot> _createSequentialSpotsFromProcessed(
      List<Map<String, dynamic>> processedRecords,
      String valueKey // Key in the map to use for the Y-value ('value_avg', 'systolic_avg', etc.)
      ) {
    return processedRecords.asMap().entries.map((e) {
      final x = e.key.toDouble(); // Sequential index 0, 1, 2, ...
      final y = e.value[valueKey] as double;
      return FlSpot(x, y);
    }).toList();
  }

  // Common styles for axis titles
  static const TextStyle _titleStyle = TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 9, // Slightly smaller font for date
  );

  // Date format for X-axis display
  static final DateFormat _dateFormatDisplay = DateFormat('d/M/yy');

  // Date format for unique keying
  static final DateFormat _dateFormatKey = DateFormat('yyyy-MM-dd');

  // --- 1. Glucose Titles ---
  static FlTitlesData _glucoseTitlesData(List<Map<String, dynamic>> processedRecords) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, // Ensure enough vertical space for the date label
          // Calculate interval to show max 5-7 labels.
          interval: (processedRecords.length / 5).clamp(1.0, double.infinity).floorToDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            // Ensure title is only drawn for valid, integer indices
            if (index >= 0 && index < processedRecords.length) {
              final date = processedRecords[index]['date'] as DateTime;
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormatDisplay.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Avg. Value', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          // --- CHANGE: Reduced interval from 50 to 25 to show more Y-axis points/labels
          interval: 25,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              space: 8.0,
              child: Text(value.toInt().toString(), style: _titleStyle),
              meta: meta,
            );
          },
        ),
      ),
    );
  }

  // --- 2. BP Titles ---
  static FlTitlesData _bpTitlesData(List<Map<String, dynamic>> processedRecords) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, // Ensure enough vertical space for the date label
          interval: (processedRecords.length / 5).clamp(1.0, double.infinity).floorToDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            // Ensure title is only drawn for valid, integer indices
            if (index >= 0 && index < processedRecords.length) {
              final date = processedRecords[index]['date'] as DateTime;
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormatDisplay.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Avg. BP (mmHg)', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          // --- CHANGE: Reduced interval from 20 to 10 to show more Y-axis points/labels
          interval: 10,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              space: 8.0,
              child: Text(value.toInt().toString(), style: _titleStyle),
              meta: meta,
            );
          },
        ),
      ),
    );
  }

  // --- 3. Pulse Titles ---
  static FlTitlesData _pulseTitlesData(List<Map<String, dynamic>> processedRecords) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, // Ensure enough vertical space for the date label
          interval: (processedRecords.length / 5).clamp(1.0, double.infinity).floorToDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            // Ensure title is only drawn for valid, integer indices
            if (index >= 0 && index < processedRecords.length) {
              final date = processedRecords[index]['date'] as DateTime;
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormatDisplay.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Avg. Pulse (bpm)', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          // --- CHANGE: Reduced interval from 10 to 5 to show more Y-axis points/labels
          interval: 5,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              space: 8.0,
              child: Text(value.toInt().toString(), style: _titleStyle),
              meta: meta,
            );
          },
        ),
      ),
    );
  }


  static Widget buildGlucoseChart(List<SugarRecord> records) {
    // 1. Process records to get one average value per date
    final processedRecords = _processRecordsByDate<SugarRecord>(
        records,
            (r) => _dateFormatKey.format(r.date),
            (r) => r.value.toDouble()
    );

    // 2. Create spots from processed (averaged) data
    final spots = _createSequentialSpotsFromProcessed(processedRecords, 'value_avg');

    // Only calculate actual max Y from the real data for correct +5 calculation
    final actualMaxY = processedRecords.isNotEmpty
        ? processedRecords.map((r) => r['value_avg'] as double).reduce(max)
        : 100.0;

    // --- Apply Padding (Empty Dataset) and MaxX Calculation ---
    double maxX = spots.isEmpty ? 0 : spots.length.toDouble() - 1; // Last real spot's X index

    if (spots.isNotEmpty) {
      // Add padding spot at the end to ensure empty space (2 index units of padding)
      final double paddingX = maxX + 1.0;
      // Add a point with the last known Y value to prevent the line from dropping to 0.0,
      // ensuring the visual trend is maintained until the end of the chart boundary.
      spots.add(FlSpot(paddingX, spots.last.y));
      maxX = paddingX; // Max X is now the padding spot's X index
    }

    // Calculate minY and revert maxY to +5 (Default Standard Positioning)
    final minY = spots.isNotEmpty ? spots.map((s) => s.y).reduce(min) - 10 : 0;
    // --- CHANGE: Increased buffer from 5.0 to 10.0 for better top spacing
    final maxY = actualMaxY + 10.0;

    // Reduced chart width buffer (original logic was +250.0, reverting to a smaller +100.0 buffer)
    final chartWidth = max(350.0, processedRecords.length * 70.0) + 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: SizedBox(
        width: chartWidth, // Set a wide width for scrolling
        child: LineChart(
          LineChartData(
            minY: minY.floorToDouble(), // Dynamic Y min
            maxY: maxY.ceilToDouble(), // Reverted to max + 5
            minX: 0,
            maxX: maxX, // Includes the new padding spot
            // Use the processed list for titles data
            titlesData: _glucoseTitlesData(processedRecords),
            gridData: const FlGridData(show: true), // Show grid for readability
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.redAccent,
                barWidth: 2,
                dotData: const FlDotData(show: true), // <--- SHOW DOTS
              ),
            ],
            // Add a simple legend/tooltip to show what the line represents
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: maxY.ceilToDouble() - 5, // Placement adjusted by the new maxY value
                  color: Colors.redAccent,
                  strokeWidth: 0,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    labelResolver: (line) => ' Avg. Glucose Trend ',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } //end buildGlucoseChart

  // Build charts for blood pressure (systolic and diastolic)
  static Widget buildBPChart(List<BPRecord> records) {
    // 1. Process records to get one average value per date
    final processedRecords = _processRecordsByDate<BPRecord>(
        records,
            (r) => _dateFormatKey.format(r.date),
            (r) => r.systolic.toDouble() // Placeholder value selector, the map will contain all three averages
    );

    // 2. Create spots from processed (averaged) data
    final systolicSpots = _createSequentialSpotsFromProcessed(processedRecords, 'systolic_avg');
    final diastolicSpots = _createSequentialSpotsFromProcessed(processedRecords, 'diastolic_avg');

    // Combine all values for Y-axis calculation
    final allValues = [...systolicSpots.map((s) => s.y), ...diastolicSpots.map((s) => s.y)];

    // Only calculate actual max Y from the real data for correct +5 calculation
    final actualMaxY = allValues.isEmpty ? 0 : allValues.reduce(max);

    // --- Apply Padding (Empty Dataset) and MaxX Calculation ---
    double maxX = processedRecords.isEmpty ? 0 : processedRecords.length.toDouble() - 1; // Last real spot's X index

    if (processedRecords.isNotEmpty) {
      // Add padding spot at the end to ensure empty space (2 index units of padding)
      final double paddingX = maxX + 1.0;

      // Get the last real data point's Y values
      final lastSystolicY = systolicSpots.last.y;
      final lastDiastolicY = diastolicSpots.last.y;

      // Add padding spots to BOTH datasets
      systolicSpots.add(FlSpot(paddingX, lastSystolicY));
      diastolicSpots.add(FlSpot(paddingX, lastDiastolicY));

      maxX = paddingX; // Max X is now the padding spot's X index
    }

    // Calculate minY and revert maxY to +5 (Default Standard Positioning)
    final minY = allValues.isEmpty ? 0 : allValues.reduce(min) - 10;
    // --- CHANGE: Increased buffer from 5.0 to 10.0 for better top spacing
    final maxY = actualMaxY + 10.0;

    // Reduced chart width buffer (original logic was +250.0, reverting to a smaller +100.0 buffer)
    final chartWidth = max(350.0, processedRecords.length * 70.0) + 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: SizedBox(
        width: chartWidth, // Set a wide width for scrolling
        child: LineChart(
          LineChartData(
            minY: minY.floorToDouble(),
            maxY: maxY.ceilToDouble(), // Reverted to max + 5
            minX: 0,
            maxX: maxX, // Includes the new padding spot
            // Use the processed list for titles data
            titlesData: _bpTitlesData(processedRecords),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
            lineBarsData: [
              LineChartBarData(
                spots: systolicSpots,
                isCurved: true,
                color: Colors.blue,
                barWidth: 2,
                dotData: const FlDotData(show: true), // <--- SHOW DOTS
              ),
              LineChartBarData(
                spots: diastolicSpots,
                isCurved: true,
                color: Colors.green,
                barWidth: 2,
                dotData: const FlDotData(show: true), // <--- SHOW DOTS
              ),
            ],
            // Add a simple legend/tooltip to show what the lines represent
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: maxY.ceilToDouble() - 5, // Placement adjusted by the new maxY value
                  color: Colors.blue,
                  strokeWidth: 0,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    labelResolver: (line) => ' Avg. Systolic ',
                  ),
                ),
                HorizontalLine(
                  y: maxY.ceilToDouble() - 8, // Second line placed 2 units lower
                  color: Colors.green,
                  strokeWidth: 0,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    labelResolver: (line) => ' Avg. Diastolic ',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } //end buildBPChart

  // Build chart for pulse rate
  static Widget buildPulseChart(List<BPRecord> records) {
    // 1. Process records to get one average value per date
    final processedRecords = _processRecordsByDate<BPRecord>(
        records,
            (r) => _dateFormatKey.format(r.date),
            (r) => r.pulseRate.toDouble() // Placeholder value selector
    );

    // 2. Create spots from processed (averaged) data
    final spots = _createSequentialSpotsFromProcessed(processedRecords, 'pulse_avg');

    // Only calculate actual max Y from the real data for correct +5 calculation
    final actualMaxY = processedRecords.isNotEmpty
        ? processedRecords.map((r) => r['pulse_avg'] as double).reduce(max)
        : 100.0;

    // --- Apply Padding (Empty Dataset) and MaxX Calculation ---
    double maxX = spots.isEmpty ? 0 : spots.length.toDouble() - 1; // Last real spot's X index

    if (spots.isNotEmpty) {
      // Add padding spot at the end to ensure empty space (2 index units of padding)
      final double paddingX = maxX + 1.0;
      spots.add(FlSpot(paddingX, spots.last.y));
      maxX = paddingX; // Max X is now the padding spot's X index
    }

    // Calculate minY and revert maxY to +5 (Default Standard Positioning)
    final minY = spots.isNotEmpty ? spots.map((s) => s.y).reduce(min) - 10 : 0;
    // --- CHANGE: Increased buffer from 5.0 to 10.0 for better top spacing
    final maxY = actualMaxY + 10.0;

    // Reduced chart width buffer (original logic was +250.0, reverting to a smaller +100.0 buffer)
    final chartWidth = max(350.0, processedRecords.length * 70.0) + 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: SizedBox(
        width: chartWidth, // Set a wide width for scrolling
        child: LineChart(
          LineChartData(
            minY: minY.floorToDouble(),
            maxY: maxY.ceilToDouble(), // Reverted to max + 5
            minX: 0,
            maxX: maxX, // Includes the new padding spot
            // Use the processed list for titles data
            titlesData: _pulseTitlesData(processedRecords),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.purple,
                barWidth: 2,
                dotData: const FlDotData(show: true), // <--- SHOW DOTS
              ),
            ],
            // Add a simple legend/tooltip
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: maxY.ceilToDouble() - 5, // Placement adjusted by the new maxY value
                  color: Colors.purple,
                  strokeWidth: 0,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                    labelResolver: (line) => ' Avg. Pulse Trend ',
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // debugPrint('attempt $attempts: boundary null');
      } else {
        bool needsPaint = false;
        if (kDebugMode) {
          needsPaint = boundary.debugNeedsPaint;
        }
        if (needsPaint) {
          // debugPrint('attempt $attempts: boundary needs paint');
        } else {
          // Add a very slight delay even after checking needsPaint for safety
          await Future.delayed(const Duration(milliseconds: 50));
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData?.buffer.asUint8List();
          if (bytes != null && bytes.isNotEmpty) {
            // debugPrint('capture done, bytes length: ${bytes.length}');
            return bytes;
          }
        }
      }
      attempts++;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // Return empty Uint8List instead of throwing an exception
    debugPrint('Failed to capture image after $maxRetries attempts. Returning empty image.');
    return Uint8List(0);
  }

}
