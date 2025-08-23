class AppSettings {
  String themeName;
  String measurementUnit;

  AppSettings({
    this.themeName = 'Light',
    this.measurementUnit = 'Metric',
  });

  Map<String, dynamic> toMap() {
    return {
      'themeName': themeName,
      'measurementUnit': measurementUnit,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeName: map['themeName'] ?? 'Light',
      measurementUnit: map['measurementUnit'] ?? 'Metric',
    );
  }
}
