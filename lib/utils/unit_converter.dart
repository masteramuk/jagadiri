class UnitConverter {
  // Conversion factor for glucose (mmol/L to mg/dL)
  static const double GLUCOSE_CONVERSION_FACTOR = 18.018;

  /// Convert height between Metric (cm) and US (inches)
  static double convertHeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'Metric' && toUnit == 'US') {
      // cm to inches
      return value / 2.54;
    } else if (fromUnit == 'US' && toUnit == 'Metric') {
      // inches to cm
      return value * 2.54;
    }
    return value; // Fallback (should not happen)
  }

  /// Convert weight between Metric (kg) and US (lbs)
  static double convertWeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'Metric' && toUnit == 'US') {
      // kg to lbs
      return value * 2.20462;
    } else if (fromUnit == 'US' && toUnit == 'Metric') {
      // lbs to kg
      return value / 2.20462;
    }
    return value; // Fallback (should not happen)
  }

  /// Convert blood sugar from mmol/L to mg/dL
  static double mmolToMgPerDl(double mmol) {
    return mmol * GLUCOSE_CONVERSION_FACTOR;
  }

  /// Convert blood sugar from mg/dL to mmol/L
  static double mgPerDlToMmol(double mg) {
    return mg / GLUCOSE_CONVERSION_FACTOR;
  }

  /// Convert blood sugar between units
  /// Example: `convertSugar(5.5, 'Metric', 'US')` → returns ~99 mg/dL
  static double convertSugar(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'Metric' && toUnit == 'US') {
      return mmolToMgPerDl(value);
    } else if (fromUnit == 'US' && toUnit == 'Metric') {
      return mgPerDlToMmol(value);
    }
    return value; // Fallback
  }

// Add more conversion methods as needed (e.g., temperature, etc.)
}