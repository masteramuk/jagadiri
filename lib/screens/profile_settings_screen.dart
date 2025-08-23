import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:jagadiri/utils/app_themes.dart';
import 'package:jagadiri/providers/theme_provider.dart';
import 'package:jagadiri/utils/unit_converter.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;

  UserProfile? _userProfile;
  String _selectedThemeName = 'Light';
  String _selectedMeasurementUnit = 'Metric';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _targetWeightController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    _userProfile = await databaseService.getUserProfile();
    _selectedThemeName = await databaseService.getSetting('themeName') ?? 'Light';
    _selectedMeasurementUnit = await databaseService.getSetting('measurementUnit') ?? 'Metric';

    if (_userProfile != null) {
      _nameController.text = _userProfile!.name;
      _dobController.text = DateFormat('yyyy-MM-dd').format(_userProfile!.dob);
      _heightController.text = _userProfile!.height.toStringAsFixed(1);
      _weightController.text = _userProfile!.weight.toStringAsFixed(1);
      _targetWeightController.text = _userProfile!.targetWeight.toStringAsFixed(1);
    }
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _userProfile?.dob ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) {
      return 'Underweight';
    } else if (bmi >= 18.5 && bmi < 24.9) {
      return 'Normal weight';
    } else if (bmi >= 25 && bmi < 29.9) {
      return 'Overweight';
    } else {
      return 'Obesity';
    }
  }

  String _getAdvice(UserProfile profile) {
    String advice = 'General advice: Maintain a balanced diet and regular exercise.';
    if (profile.bmi < 18.5) {
      advice = 'You are underweight. Consider consulting a doctor or nutritionist to gain weight healthily.';
    } else if (profile.bmi >= 25) {
      advice = 'You are overweight or obese. Focus on a calorie-controlled diet and increased physical activity.';
    }

    if (profile.weight > profile.targetWeight) {
      advice += ' You are currently above your target weight. Focus on gradual weight loss.';
    } else if (profile.weight < profile.targetWeight) {
      advice += ' You are currently below your target weight. Ensure healthy weight gain if that is your goal.';
    } else {
      advice += ' You are at your target weight. Great job! Maintain your healthy habits.';
    }
    return advice;
  }

  Future<void> _saveSettings() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    // Save Theme
    await databaseService.insertSetting('themeName', _selectedThemeName);
    Provider.of<ThemeProvider>(context, listen: false).setTheme(_selectedThemeName);

    // Save Measurement Unit
    await databaseService.insertSetting('measurementUnit', _selectedMeasurementUnit);

    // Save User Profile
    if (_formKey.currentState!.validate()) {
      final newProfile = UserProfile(
        id: _userProfile?.id, // Use existing ID if updating
        name: _nameController.text,
        dob: DateTime.parse(_dobController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        targetWeight: double.parse(_targetWeightController.text),
        measurementUnit: _selectedMeasurementUnit, // Use the selected unit
      );

      try {
        if (_userProfile == null) {
          await databaseService.insertUserProfile(newProfile);
        } else {
          await databaseService.updateUserProfile(newProfile);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings and Profile saved successfully!')),
        );
        _loadSettings(); // Reload to update BMI and advice
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: \${e.toString()}')),
        );
      }
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
            // App Preferences Section
            Text(
              'App Preferences',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('Theme'),
              trailing: DropdownButton<String>(
                value: _selectedThemeName,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedThemeName = newValue!;
                  });
                },
                items: AppThemes.themes.keys.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            ListTile(
              title: const Text('Measurement Unit'),
              trailing: DropdownButton<String>(
                value: _selectedMeasurementUnit,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMeasurementUnit = newValue!;
                  });
                },
                items: <String>['Metric', 'US']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            // User Profile Section
            Text(
              'User Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _dobController,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your date of birth';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(labelText: 'Height (${_selectedMeasurementUnit == 'Metric' ? 'cm' : 'inches'})'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your height';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(labelText: 'Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your weight';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _targetWeightController,
                    decoration: InputDecoration(labelText: 'Target Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your target weight';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_userProfile != null) ...[
                    Text(
                      'BMI: ${_userProfile!.bmi.toStringAsFixed(2)} (${_getBMICategory(_userProfile!.bmi)})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current Weight: ${_userProfile!.weight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Target Weight: ${_userProfile!.targetWeight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Advice: ${_getAdvice(_userProfile!)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
