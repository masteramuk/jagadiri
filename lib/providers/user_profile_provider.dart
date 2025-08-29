import 'package:flutter/foundation.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/services/database_service.dart';

class UserProfileProvider with ChangeNotifier {
  UserProfile? _userProfile;
  String _currentUnit = 'Metric'; // Default value

  UserProfile? get userProfile => _userProfile;
  String get currentUnit => _currentUnit;

  // Constructor to load initial data
  UserProfileProvider() {
    _loadUserProfileAndSettings();
  }

  Future<void> _loadUserProfileAndSettings() async {
    final db = DatabaseService(); // Use direct instance as Provider might not be available yet
    _userProfile = await db.getUserProfile();
    _currentUnit = await db.getSetting('measurementUnit') ?? 'Metric';
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile newProfile) async {
    final db = DatabaseService();
    if (newProfile.id == null) {
      await db.insertUserProfile(newProfile);
    } else {
      await db.updateUserProfile(newProfile);
    }
    _userProfile = newProfile; // Update local state
    notifyListeners(); // Notify listeners that profile has changed
  }

  Future<void> updateMeasurementUnit(String newUnit) async {
    final db = DatabaseService();
    await db.insertSetting('measurementUnit', newUnit);
    _currentUnit = newUnit;
    notifyListeners(); // Notify listeners that unit has changed
  }
}