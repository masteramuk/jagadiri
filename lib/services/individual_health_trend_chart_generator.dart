import 'dart:math';
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

  // Utility to create a list of FlSpot objects from records with dates
  static List<FlSpot> _createDateSpots<T>(
      List<T> records, DateTime Function(T) dateSelector, double Function(T) valueSelector) {
    if (records.isEmpty) {
      return [];
    }

    final firstDate = dateSelector(records.first);
    return records.map((record) {
      final date = dateSelector(record);
      final x = date.difference(firstDate).inDays.toDouble();
      final y = valueSelector(record);
      return FlSpot(x, y);
    }).toList();
  }

  // --- Chart Building Methods ---

  // Utility to create a sequential list of FlSpot objects
  static List<FlSpot> _createSequentialSpots<T>(List<T> records, double Function(T) valueSelector) {
    return records.asMap().entries.map((e) {
      final x = e.key.toDouble(); // Sequential index 0, 1, 2, ...
      final y = valueSelector(e.value);
      return FlSpot(x, y);
    }).toList();
  }

  // Common styles for axis titles
  static const TextStyle _titleStyle = TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 10,
  );

  // Date format for X-axis
  static final DateFormat _dateFormat = DateFormat('d/M/yy'); // New condensed format

  // --- 1. Glucose Titles ---
  static FlTitlesData _glucoseTitlesData(List<SugarRecord> records) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: (records.length / 5).clamp(1.0, 5.0).toDouble(), // Show max 5 labels, minimum 1 interval
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < records.length) {
              final date = records[index].date;
              // Display the date (e.g., 15/8/24)
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormat.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Value', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          interval: 50, // Standard interval for glucose (50 mg/dL)
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
  static FlTitlesData _bpTitlesData(List<BPRecord> records) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: (records.length / 5).clamp(1.0, 5.0).toDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < records.length) {
              final date = records[index].date;
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormat.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('BP (mmHg)', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          interval: 20, // Standard interval for BP
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
  static FlTitlesData _pulseTitlesData(List<BPRecord> records) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Record Date', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: (records.length / 5).clamp(1.0, 5.0).toDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < records.length) {
              final date = records[index].date;
              return SideTitleWidget(
                space: 4.0,
                child: Text(_dateFormat.format(date), style: _titleStyle),
                meta: meta,
              );
            }
            return Container();
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Pulse (bpm)', style: _titleStyle),
        sideTitles: SideTitles(
          showTitles: true,
          interval: 10, // Standard interval for pulse
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

  /*
  static Widget buildGlucoseChart(List<SugarRecord> records) {
    if (records.isEmpty) return const Center(child: Text('No data'));

    final spots = _createDateSpots(records, (r) => r.date, (r) => r.value.toDouble());

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.last.x,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = records.first.date.add(Duration(days: value.toInt()));
                      return SideTitleWidget(
                        fitInside: meta.axisSide,
                        child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                      );
                    },
                    interval: (spots.last.x / 5).ceilToDouble(), // Show around 5 labels
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  axisNameWidget: const Text('mg/dL'),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.redAccent,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final record = records[spot.spotIndex];
                      return LineTooltipItem(
                        '${record.value.toStringAsFixed(1)} mg/dL\n${DateFormat('dd/MM/yyyy').format(record.date)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Legend(title: 'Glucose', color: Colors.redAccent),
      ],
    );
  } //end buildGlucoseChart

  static Widget buildBPChart(List<BPRecord> records) {
    if (records.isEmpty) return const Center(child: Text('No data'));

    final systolicSpots = _createDateSpots(records, (r) => r.date, (r) => r.systolic.toDouble());
    final diastolicSpots = _createDateSpots(records, (r) => r.date, (r) => r.diastolic.toDouble());

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: systolicSpots.last.x,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = records.first.date.add(Duration(days: value.toInt()));
                      return SideTitleWidget(
                        fitInside: meta.axisSide,
                        child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                      );
                    },
                    interval: (systolicSpots.last.x / 5).ceilToDouble(),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  axisNameWidget: const Text('mmHg'),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
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
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final record = records[spot.spotIndex];
                      final isSystolic = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isSystolic ? record.systolic : record.diastolic} mmHg\n${DateFormat('dd/MM/yyyy').format(record.date)}',
                        TextStyle(color: isSystolic ? Colors.blue : Colors.green),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Legend(title: 'Systolic', color: Colors.blue),
            Legend(title: 'Diastolic', color: Colors.green),
          ],
        ),
      ],
    );
  } //end buildBPChart

  static Widget buildPulseChart(List<BPRecord> records) {
    if (records.isEmpty) return const Center(child: Text('No data'));

    final spots = _createDateSpots(records, (r) => r.date, (r) => r.pulseRate.toDouble());

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.last.x,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = records.first.date.add(Duration(days: value.toInt()));
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                      );
                    },
                    interval: (spots.last.x / 5).ceilToDouble(),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  axisNameWidget: const Text('bpm'),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.purple,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final record = records[spot.spotIndex];
                      return LineTooltipItem(
                        '${record.pulseRate} bpm\n${DateFormat('dd/MM/yyyy').format(record.date)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Legend(title: 'Pulse', color: Colors.purple),
      ],
    );
  } //end buildPulseChart
 */

  //new methods
  static Widget buildGlucoseChart(List<SugarRecord> records) {
    final spots = _createSequentialSpots(records, (r) => r.value.toDouble());
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    // Determine chart width based on the number of records.
    // For many records (e.g., > 10), we can set a fixed width per record to allow scrolling.
    final chartWidth = max(350.0, records.length * 70.0); // Minimum 350, then 70 pixels per record

    return SizedBox(
      width: chartWidth, // Set a wide width for scrolling
      child: LineChart(
        LineChartData(
          minY: minY.floorToDouble(), // Dynamic Y min
          maxY: maxY.ceilToDouble(), // Dynamic Y max
          minX: 0,
          maxX: spots.isEmpty ? 0 : spots.length.toDouble() - 1,
          // Use the new Glucose title data, passing the original records list
          titlesData: _glucoseTitlesData(records),
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
                y: maxY.ceilToDouble() - 1, // Place near the top
                color: Colors.redAccent,
                strokeWidth: 0,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  labelResolver: (line) => ' Glucose Trend ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } //end buildGlucoseChart

  // Build charts for blood pressure (systolic and diastolic)
  static Widget buildBPChart(List<BPRecord> records) {
    final systolicSpots = _createSequentialSpots(records, (r) => r.systolic.toDouble());
    final diastolicSpots = _createSequentialSpots(records, (r) => r.diastolic.toDouble());

    final allValues = [...systolicSpots.map((s) => s.y), ...diastolicSpots.map((s) => s.y)];
    final minY = allValues.isEmpty ? 0 : allValues.reduce((a, b) => a < b ? a : b) - 10;
    final maxY = allValues.isEmpty ? 0 : allValues.reduce((a, b) => a > b ? a : b) + 10;

    final double maxX = records.isEmpty ? 0 : records.length.toDouble() - 1;

    // Determine chart width based on the number of records.
    final chartWidth = max(350.0, records.length * 70.0); // Minimum 350, then 70 pixels per record

    return SizedBox(
      width: chartWidth, // Set a wide width for scrolling
      child: LineChart(
        LineChartData(
          minY: minY.floorToDouble(),
          maxY: maxY.ceilToDouble(),
          minX: 0,
          maxX: maxX,
          // Use the new BP title data, passing the original records list
          titlesData: _bpTitlesData(records),
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
                y: maxY.ceilToDouble() - 1, // Place near the top
                color: Colors.blue,
                strokeWidth: 0,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  labelResolver: (line) => ' Systolic ',
                ),
              ),
              HorizontalLine(
                y: maxY.ceilToDouble() - 10, // Place slightly below systolic label
                color: Colors.green,
                strokeWidth: 0,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  labelResolver: (line) => ' Diastolic ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } //end buildBPChart

  // Build chart for pulse rate
  static Widget buildPulseChart(List<BPRecord> records) {
    final spots = _createSequentialSpots(records, (r) => r.pulseRate.toDouble());
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    // Determine chart width based on the number of records.
    final chartWidth = max(350.0, records.length * 70.0); // Minimum 350, then 70 pixels per record

    return SizedBox(
      width: chartWidth, // Set a wide width for scrolling
      child: LineChart(
        LineChartData(
          minY: minY.floorToDouble(),
          maxY: maxY.ceilToDouble(),
          minX: 0,
          maxX: spots.isEmpty ? 0 : spots.length.toDouble() - 1,
          // Use the new Pulse title data, passing the original records list
          titlesData: _pulseTitlesData(records),
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
                y: maxY.ceilToDouble() - 1, // Place near the top
                color: Colors.purple,
                strokeWidth: 0,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                  labelResolver: (line) => ' Pulse Trend ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } //end buildPulseChart

  //end new methds
  // --- IMAGE CAPTURE METHOD (No changes needed, this looks robust) ---

  // Capture chart as image
  /*
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
  }*/

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

class Legend extends StatelessWidget {
  final String title;
  final Color color;
  final bool show;

  const Legend({super.key, required this.title, required this.color, this.show = true});

  @override
  Widget build(BuildContext context) {
    if (!show) return Container();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
