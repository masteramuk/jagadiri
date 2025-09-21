import 'dart:math';

import 'package:collection/collection.dart';

import '../models/bp_record.dart';
import '../models/sugar_record.dart';
import '../models/user_profile.dart';

class HealthAnalysisService {
  final Random _random = Random();
  /// Generates comprehensive health analysis text for any report.
  /// Reusable across all 5 report types.
  String generateAnalysisText({
    required List<SugarRecord> sugarReadings,
    required List<BPRecord> bpReadings,
    required UserProfile userProfile,
  }) {
    if (sugarReadings.isEmpty && bpReadings.isEmpty) {
      return "No health data is available for analysis. Please start by recording your glucose or blood pressure readings.";
    }

    final summary = StringBuffer();
    summary.writeln("Here is your personalized health analysis based on your recent data, ${userProfile.name}.");
    summary.writeln();

    // Generate and append each section
    summary.write(_generateGlucoseAnalysis(sugarReadings, userProfile));
    summary.write(_generateBPAnalysis(bpReadings));
    summary.write(_generatePulseAnalysis(bpReadings));
    summary.write(_generateTrendAndFluctuationAnalysis(sugarReadings, bpReadings, userProfile));
    summary.writeln();

    summary.writeln("💡 Wellness Tips:");
    summary.writeln(_getWellnessTips());

    return summary.toString();
  }

  // --- Private Analysis Methods ---

  String _generateGlucoseAnalysis(List<SugarRecord> _sugarReadings, UserProfile _userProfile) {
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
      buffer.writeln("- You had $highEvents instance(s) of high glucose (>180 mg/dL). ${_getNlgTemplate('glucose_high')}");
    }
    if (lowEvents > 0) {
      buffer.writeln("- You experienced $lowEvents episode(s) of low glucose (<70 mg/dL). ${_getNlgTemplate('glucose_low')}");
    }

    buffer.writeln();
    return buffer.toString();
  }

  String _generateBPAnalysis(List<BPRecord> _bpReadings) {
    if (_bpReadings.isEmpty) return "";
    final buffer = StringBuffer();

    final avgSystolic = _bpReadings.map((r) => r.systolic).average.round();
    final avgDiastolic = _bpReadings.map((r) => r.diastolic).average.round();

    buffer.writeln("❤️ Blood Pressure Insights:");
    buffer.writeln("Your average BP is **$avgSystolic/$avgDiastolic mmHg**.");

    // AHA Classification
    buffer.write("This falls into the ");
    if (avgSystolic < 120 && avgDiastolic < 80) {
      buffer.writeln("**Normal** category. Great job! ✅");
    } else if (avgSystolic < 130 && avgDiastolic < 80) {
      buffer.writeln("**Elevated** category.");
    } else if (avgSystolic < 140 || avgDiastolic < 90) {
      buffer.writeln("**Hypertension Stage 1** category.");
    } else if (avgSystolic < 180 || avgDiastolic < 120) {
      buffer.writeln("**Hypertension Stage 2** category.");
    } else {
      buffer.writeln("**Hypertensive Crisis** category. Please consult a doctor immediately. 🚨");
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
      buffer.writeln("- On $unstableDays day(s), your systolic BP varied by more than 20 mmHg. ${_getNlgTemplate('bp_unstable')}");
    }

    buffer.writeln();
    return buffer.toString();
  }

  String _generatePulseAnalysis(List<BPRecord> _bpReadings) {
    if (_bpReadings.isEmpty) return "";
    final buffer = StringBuffer();
    final avgPulse = _bpReadings.map((r) => r.pulseRate).average.round();

    buffer.writeln("💓 Pulse Rate Insights:");
    buffer.writeln("Your average resting pulse is **$avgPulse bpm**.");

    if (avgPulse < 60) {
      buffer.writeln("- This may indicate bradycardia (a slow heart rate). ${_getNlgTemplate('pulse_low')}");
    } else if (avgPulse > 100) {
      buffer.writeln("- This may indicate tachycardia (a fast heart rate). ${_getNlgTemplate('pulse_high')}");
    } else {
      buffer.writeln("- Your pulse is in the normal range. Keep up the healthy habits! 👍");
    }
    buffer.writeln();
    return buffer.toString();
  }

  String _generateTrendAndFluctuationAnalysis(List<SugarRecord> _sugarReadings, List<BPRecord> _bpReadings, UserProfile _userProfile) {
    if (_sugarReadings.isEmpty) return "";

    final buffer = StringBuffer();
    buffer.writeln("📈 Trends & Fluctuations:");

    // Simple trend detection (comparing first half vs second half)
    if (_sugarReadings.length > 4) {
      final firstHalfAvg = _sugarReadings.sublist(0, _sugarReadings.length ~/ 2).map((r) => r.value).average;
      final secondHalfAvg = _sugarReadings.sublist(_sugarReadings.length ~/ 2).map((r) => r.value).average;
      if (secondHalfAvg > firstHalfAvg * 1.1) {
        buffer.writeln("- Your glucose levels appear to be on a **rising trend**. ${_getNlgTemplate('glucose_trend_up')}");
      } else if (secondHalfAvg < firstHalfAvg * 0.9) {
        buffer.writeln("- Good news! Your glucose levels show a **falling trend**. ${_getNlgTemplate('glucose_trend_down')}");
      } else {
        buffer.writeln("- Your glucose levels are relatively **stable**. ${_getNlgTemplate('glucose_stable')}");
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
      buffer.writeln("- We noticed significant glucose swings (>60 mg/dL) on $highFluctuationDays day(s). ${_getNlgTemplate('glucose_fluctuation')}");
    }

    // Personalization
    if (_userProfile.sugarScenario == 'Type 1 Diabetic') {
      buffer.writeln("- As a Type 1 Diabetic, precise insulin timing is key. ${_getNlgTemplate('t1_diabetic')}");
    } else if (_userProfile.sugarScenario == 'Type 2 Diabetic') {
      buffer.writeln("- For Type 2 Diabetes, combining diet and exercise is a powerful tool. ${_getNlgTemplate('t2_diabetic')}");
    }

    return buffer.toString();
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

  String _getNlgTemplate(String key) {
    final templates = {
      'glucose_high': [
        "Monitoring carb intake might help prevent these spikes. 📈",
        "Remember to check your levels after meals to understand their impact. 🤔",
        "Are these spikes related to specific foods or stress? Noting it down can help.",
      ],
      'glucose_low': [
        "Always have a quick-sugar source handy. Your safety is a priority! 🍬",
        "Be careful not to overtreat a low; recheck your levels in 15 minutes.",
        "Feeling shaky or dizzy? It might be a sign of a hypo. Please be safe.",
      ],
      'bp_unstable': [
        "This variability can be taxing. Aiming for consistency in diet and routine can help. ⚖️",
        "Factors like salt intake, stress, or even caffeine can cause these swings.",
        "Let's try to create a more stable environment for your heart.",
      ],
      'pulse_low': [
        "For athletes, a lower pulse can be a sign of great fitness! But if you feel dizzy, it's worth a check-up. 🏃",
        "Certain medications can lower heart rate. It's good to be aware.",
      ],
      'pulse_high': [
        "Stress, caffeine, or dehydration can sometimes elevate your pulse. ☕",
        "Notice if your heart races during rest; it could be a signal to slow down and breathe.",
      ],
      'glucose_trend_up': [
        "Let's review your diet and activity to see what might be causing this upward trend. Small changes can make a big difference. 💪",
        "An upward trend is a call to action. You have the power to steer it back down!",
      ],
      'glucose_trend_down': [
        "Whatever you're doing, it's working! Keep up the fantastic effort. 🎉",
        "This downward trend is a huge win for your long-term health. Celebrate it!",
      ],
      'glucose_stable': [
        "Consistency is key in diabetes management, and you are nailing it! 👏",
        "A stable trend is a sign of a balanced and healthy routine. Well done!",
      ],
      'glucose_fluctuation': [
        "Smoothing out these peaks and valleys can lead to better energy and health. Consider consistent carb timing. 🍽️",
        "Big swings can be tiring. Let's aim for a gentler wave.",
      ],
      't1_diabetic': [
        "Your diligence with insulin and carb counting is the cornerstone of your health.",
        "Navigating the T1 journey requires strength. You're doing great.",
      ],
      't2_diabetic': [
        "Every healthy meal and every step you take is a step towards reversing insulin resistance. Keep going! 🚶‍♀️",
        "Managing T2 is a marathon, not a sprint. Your consistent efforts are what count.",
      ],
    };

    if (templates.containsKey(key)) {
      final options = templates[key]!;
      return options[_random.nextInt(options.length)];
    }
    return "";
  }

}