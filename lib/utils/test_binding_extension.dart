import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;

/// Extension to safely check if TestWidgetsFlutterBinding is already initialized.
extension TestBindingExtension on flutter_test.TestWidgetsFlutterBinding {
  /// Returns true if the current WidgetsBinding is a TestWidgetsFlutterBinding.
  static bool get isInitialized => WidgetsBinding.instance is flutter_test.TestWidgetsFlutterBinding;
}