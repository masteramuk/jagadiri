class UnitConverter {
  static double convertHeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'Metric' && toUnit == 'US') {
      // Convert cm to inches
      return value / 2.54;
    } else if (fromUnit == 'US' && toUnit == 'Metric') {
      // Convert inches to cm
      return value * 2.54;
    }
    return value; // Should not happen
  }

  static double convertWeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'Metric' && toUnit == 'US') {
      // Convert kg to lbs
      return value * 2.20462;
    } else if (fromUnit == 'US' && toUnit == 'Metric') {
      // Convert lbs to kg
      return value / 2.20462;
    }
    return value; // Should not happen
  }

  // Add more conversion methods as needed (e.g., for blood pressure, sugar if units differ)
}
