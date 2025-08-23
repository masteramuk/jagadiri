import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isDarkMode = false; // Dummy setting
  String _selectedUnit = 'mg/dL'; // Default sugar unit

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _selectedUnit = prefs.getString('sugarUnit') ?? 'mg/dL'; // Load sugar unit
    });
  }

  Future<void> _saveThemeSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dark mode set to: \$value')),
    );
  }

  Future<void> _saveSugarUnit(String? value) async {
    if (value != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sugarUnit', value);
      setState(() {
        _selectedUnit = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sugar unit set to: \$value')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Preferences',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: _isDarkMode,
              onChanged: _saveThemeSetting,
            ),
            ListTile(
              title: const Text('Sugar Measurement Unit'),
              trailing: DropdownButton<String>(
                value: _selectedUnit,
                onChanged: _saveSugarUnit,
                items: <String>['mg/dL', 'mmol/L']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
              ),
            ),
            // Add more settings here
          ],
        ),
      ),
    );
  }
}