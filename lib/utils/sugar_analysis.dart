import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/sugar_reference.dart';

/// NEW:  synchronous, no DB access, uses the pre-loaded reference
SugarStatus analyseStatus({
  required List<SugarRecord> records,
  required String unit,
  required SugarReference ref,   // <-- pass the already-loaded row
}) {
  if (records.isEmpty) return SugarStatus.good;

  final averageValue =
      records.map((r) => r.value).reduce((a, b) => a + b) / records.length;

  final min = unit == 'Metric' ? ref.minMmolL : ref.minMgdL;
  final max = unit == 'Metric' ? ref.maxMmolL : ref.maxMgdL;

  final range = max - min;
  final borderlineThreshold = range * 0.15;

  if (averageValue < min) return SugarStatus.low;
  if (averageValue > max) return SugarStatus.high;
  if (averageValue >= min + borderlineThreshold &&
      averageValue <= max - borderlineThreshold) {
    return SugarStatus.good;
  }
  if (averageValue >= min && averageValue < min + borderlineThreshold) {
    return SugarStatus.borderline;
  }
  if (averageValue > max - borderlineThreshold && averageValue <= max) {
    return SugarStatus.borderline;
  }
  return SugarStatus.excellent;
}