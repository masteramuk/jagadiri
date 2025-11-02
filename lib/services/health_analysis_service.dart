import 'dart:math';

import 'package:collection/collection.dart';

import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

class HealthAnalysisService {
  final Random _random = Random();
  final DatabaseService _dbService = DatabaseService();
  /// Generates comprehensive health analysis text for any report.
  /// Reusable across all 5 report types.
  Future<String> generateAnalysisText({
    required List<SugarRecord> sugarReadings,
    required List<BPRecord> bpReadings,
    required UserProfile userProfile,
  }) async {
    if (sugarReadings.isEmpty && bpReadings.isEmpty) {
      return "No health data is available for analysis. Please start by recording your glucose or blood pressure readings.";
    }

    final summary = StringBuffer();
    summary.writeln("Here is your personalized health analysis based on your recent data, ${userProfile.name}.");
    summary.writeln();

    // Generate and append each section
    summary.write(await _generateGlucoseAnalysis(sugarReadings, userProfile));
    summary.write(await _generateBPAnalysis(bpReadings));
    summary.write(await _generatePulseAnalysis(bpReadings));
    summary.write(await _generateTrendAndFluctuationAnalysis(sugarReadings, bpReadings, userProfile));
    summary.writeln();

    summary.writeln("💡 Wellness Tips:");
    summary.writeln(_getWellnessTips());

    return summary.toString();
  }

  // --- Private Analysis Methods ---

  Future<String> _generateGlucoseAnalysis(List<SugarRecord> _sugarReadings, UserProfile _userProfile) async {
    if (_sugarReadings.isEmpty) return "";
    final buffer = StringBuffer();

    final avgGlucose = _sugarReadings.map((r) => r.value).average;
    final fastingReadings = _sugarReadings.where((r) => r.mealTimeCategory == MealTimeCategory.before).toList();
    final postMealReadings = _sugarReadings.where((r) => r.mealTimeCategory == MealTimeCategory.after).toList();

    buffer.writeln("🩸 Glucose Insights:");
    buffer.writeln("Your average glucose is ${avgGlucose.toStringAsFixed(1)} mg/dL.");

    // Classification based on fasting glucose if available
    if (fastingReadings.isNotEmpty) {
      final avgFasting = fastingReadings.map((r) => r.value).average;
      buffer.write("Your average fasting glucose of ${avgFasting.toStringAsFixed(1)} mg/dL places you in the ");
      if (avgFasting < 100) {
        buffer.writeln("**Normal** range.");
      } else if (avgFasting <= 125) {
        buffer.writeln("**Prediabetic** range.");
      } else {
        buffer.writeln("**Diabetic** range, according to ADA guidelines.");
      }
    }

    // Hyper/Hypo events
    final highEvents = _sugarReadings.where((r) => r.value > 180).length;
    final lowEvents = _sugarReadings.where((r) => r.value < 70).length;
    if (highEvents > 0) {
      buffer.writeln("- You had $highEvents instance(s) of high glucose (>180 mg/dL). ${await _getNlgTemplate('glucose_high')}");
    }
    if (lowEvents > 0) {
      buffer.writeln("- You experienced $lowEvents episode(s) of low glucose (<70 mg/dL). ${await _getNlgTemplate('glucose_low')}");
    }

    buffer.writeln();
    return buffer.toString();
  }

  Future<String> _generateBPAnalysis(List<BPRecord> _bpReadings) async {
    if (_bpReadings.isEmpty) return "";
    final buffer = StringBuffer();

    final avgSystolic = _bpReadings.map((r) => r.systolic).average.round();
    final avgDiastolic = _bpReadings.map((r) => r.diastolic).average.round();

    buffer.writeln("❤ Blood Pressure Insights:");
    buffer.writeln("Your average BP is **$avgSystolic/$avgDiastolic mmHg**.");

    // AHA Classification
    buffer.write("This falls into the ");
    if (avgSystolic < 120 && avgDiastolic < 80) {
      buffer.writeln("**Normal** category. Great job!");
    } else if (avgSystolic < 130 && avgDiastolic < 80) {
      buffer.writeln("**Elevated** category.");
    } else if (avgSystolic < 140 || avgDiastolic < 90) {
      buffer.writeln("**Hypertension Stage 1** category.");
    } else if (avgSystolic < 180 || avgDiastolic < 120) {
      buffer.writeln("**Hypertension Stage 2** category.");
    } else {
      buffer.writeln("**Hypertensive Crisis** category. Please consult a doctor immediately.");
    }

    // Instability check
    final dailyReadings = groupBy(_bpReadings, (BPRecord r) => r.date.day);
    final unstableDays = dailyReadings.values.where((day) {
      if (day.length < 2) return false;
      final maxSystolic = day.map((r) => r.systolic).reduce(max);
      final minSystolic = day.map((r) => r.systolic).reduce(min);
      return (maxSystolic - minSystolic) > 20;
    }).length;

    if (unstableDays > 0) {
      buffer.writeln("- On $unstableDays day(s), your systolic BP varied by more than 20 mmHg. ${await _getNlgTemplate('bp_unstable')}");
    }

    buffer.writeln();
    return buffer.toString();
  }

  Future<String> _generatePulseAnalysis(List<BPRecord> _bpReadings) async {
    if (_bpReadings.isEmpty) return "";
    final buffer = StringBuffer();
    final avgPulse = _bpReadings.map((r) => r.pulseRate).average.round();

    buffer.writeln("💓 Pulse Rate Insights:");
    buffer.writeln("Your average resting pulse is **$avgPulse bpm**.");

    if (avgPulse < 60) {
      buffer.writeln("- This may indicate bradycardia (a slow heart rate). ${await _getNlgTemplate('pulse_low')}");
    } else if (avgPulse > 100) {
      buffer.writeln("- This may indicate tachycardia (a fast heart rate). ${await _getNlgTemplate('pulse_high')}");
    } else {
      buffer.writeln("- Your pulse is in the normal range. Keep up the healthy habits! 👍");
    }
    buffer.writeln();
    return buffer.toString();
  }

  Future<String> _generateTrendAndFluctuationAnalysis(List<SugarRecord> _sugarReadings, List<BPRecord> _bpReadings, UserProfile _userProfile) async {
    if (_sugarReadings.isEmpty) return "";

    final buffer = StringBuffer();
    buffer.writeln("📈 Trends & Fluctuations:");

    // Simple trend detection (comparing first half vs second half)
    if (_sugarReadings.length > 4) {
      final firstHalfAvg = _sugarReadings.sublist(0, _sugarReadings.length ~/ 2).map((r) => r.value).average;
      final secondHalfAvg = _sugarReadings.sublist(_sugarReadings.length ~/ 2).map((r) => r.value).average;
      if (secondHalfAvg > firstHalfAvg * 1.1) {
        buffer.writeln("- Your glucose levels appear to be on a **rising trend**. ${await _getNlgTemplate('glucose_trend_up')}");
      } else if (secondHalfAvg < firstHalfAvg * 0.9) {
        buffer.writeln("- Good news! Your glucose levels show a **falling trend**. ${await _getNlgTemplate('glucose_trend_down')}");
      } else {
        buffer.writeln("- Your glucose levels are relatively **stable**. ${await _getNlgTemplate('glucose_stable')}");
      }
    }

    // Fluctuation
    final dailyGlucose = groupBy(_sugarReadings, (SugarRecord r) => r.date.day);
    final highFluctuationDays = dailyGlucose.values.where((day) {
      if (day.length < 2) return false;
      final maxVal = day.map((r) => r.value).reduce(max);
      final minVal = day.map((r) => r.value).reduce(min);
      return (maxVal - minVal) > 60;
    }).length;

    if (highFluctuationDays > 0) {
      buffer.writeln("- We noticed significant glucose swings (>60 mg/dL) on $highFluctuationDays day(s). ${await _getNlgTemplate('glucose_fluctuation')}");
    }

    // Personalization
    if (_userProfile.sugarScenario == 'Type 1 Diabetic') {
      buffer.writeln("- As a Type 1 Diabetic, precise insulin timing is key. ${await _getNlgTemplate('t1_diabetic')}");
    } else if (_userProfile.sugarScenario == 'Type 2 Diabetic') {
      buffer.writeln("- For Type 2 Diabetes, combining diet and exercise is a powerful tool. ${await _getNlgTemplate('t2_diabetic')}");
    }

    return buffer.toString();
  }

  double _avg(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    final sum = records.map(selector).reduce((a, b) => a + b);
    return (sum/records.length).toDouble();
  }

  double _min(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a < b ? a : b).toDouble();
  }

  double _max(List<dynamic> records, num Function(dynamic) selector) {
    if (records.isEmpty) return 0.0;
    return records.map(selector).reduce((a, b) => a > b ? a : b).toDouble();
  }

  String _getWellnessTips() {
    const tips = [
      "💧 Morning hydration can help regulate blood pressure throughout the day.",
      "🥗 A fiber-rich breakfast can stabilize your morning glucose levels.",
      "🚶 A short 10-minute walk after meals can do wonders for your blood sugar.",
      "🧘 Deep breathing exercises for 5 minutes can help lower stress and your pulse rate.",
      "😴 Aim for 7-8 hours of quality sleep to improve insulin sensitivity."
    ];
    return tips[_random.nextInt(tips.length)];
  }

  // --- NLG Templates ---

  Future<String> generateChartDescription(String chartType, List<dynamic> records, UserProfile userProfile) async {
    if (records.isEmpty) {
      return 'No data available to generate a trend description for $chartType.';
    }

    final descriptionsFromDb = await _dbService.getChartDescriptions();
    String trend = 'stable'; // Default trend

    // Basic trend analysis (can be expanded for more sophistication)
    if (chartType == 'Glucose' && records is List<SugarRecord>) {
      final double avg = _avg(records, (r) => r.value);
      final double min = _min(records, (r) => r.value);
      final double max = _max(records, (r) => r.value);

      if (userProfile.suitableSugarMin != null && userProfile.suitableSugarMax != null) {
        if (avg > userProfile.suitableSugarMax! * 1.1) {
          trend = 'high';
        } else if (avg < userProfile.suitableSugarMin! * 0.9) {
          trend = 'low';
        } else if (max - min > (userProfile.suitableSugarMax! - userProfile.suitableSugarMin!) * 1.5) {
          trend = 'fluctuating';
        } else {
          trend = 'stable';
        }
      }
    } else if (chartType == 'Blood Pressure' && records is List<BPRecord>) {
      final double avgSystolic = _avg(records, (r) => r.systolic);
      final double avgDiastolic = _avg(records, (r) => r.diastolic);
      final double minSystolic = _min(records, (r) => r.systolic);
      final double maxSystolic = _max(records, (r) => r.systolic);
      final double minDiastolic = _min(records, (r) => r.diastolic);
      final double maxDiastolic = _max(records, (r) => r.diastolic);

      if (userProfile.suitableSystolicMin != null && userProfile.suitableSystolicMax != null &&
          userProfile.suitableDiastolicMin != null && userProfile.suitableDiastolicMax != null) {
        if (avgSystolic > userProfile.suitableSystolicMax! * 1.1 || avgDiastolic > userProfile.suitableDiastolicMax! * 1.1) {
          trend = 'high';
        } else if (avgSystolic < userProfile.suitableSystolicMin! * 0.9 || avgDiastolic < userProfile.suitableDiastolicMin! * 0.9) {
          trend = 'low';
        } else if ((maxSystolic - minSystolic > (userProfile.suitableSystolicMax! - userProfile.suitableSystolicMin!) * 1.5) ||
                   (maxDiastolic - minDiastolic > (userProfile.suitableDiastolicMax! - userProfile.suitableDiastolicMin!) * 1.5)) {
          trend = 'fluctuating';
        } else {
          trend = 'stable';
        }
      }
    } else if (chartType == 'Pulse' && records is List<BPRecord>) {
      final double avg = _avg(records, (r) => r.pulseRate);
      final double min = _min(records, (r) => r.pulseRate);
      final double max = _max(records, (r) => r.pulseRate);

      if (userProfile.suitablePulseMin != null && userProfile.suitablePulseMax != null) {
        if (avg > userProfile.suitablePulseMax! * 1.1) {
          trend = 'high';
        } else if (avg < userProfile.suitablePulseMin! * 0.9) {
          trend = 'low';
        } else if (max - min > (userProfile.suitablePulseMax! - userProfile.suitablePulseMin!) * 1.5) {
          trend = 'fluctuating';
        } else {
          trend = 'stable';
        }
      }
    }

    final List<String>? descriptions = descriptionsFromDb[chartType]?[trend];
    if (descriptions != null && descriptions.isNotEmpty) {
      return descriptions[_random.nextInt(descriptions.length)];
    }
    return 'No specific trend description available for $chartType with trend $trend.';
  }

  Future<String> _getNlgTemplate(String key) async {
    final templates = await _dbService.getNlgTemplates();

    if (templates.containsKey(key)) {
      final options = templates[key]!;
      return options[_random.nextInt(options.length)];
    }
    return "";
  }

}