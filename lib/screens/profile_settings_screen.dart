import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:jagadiri/utils/app_themes.dart';
import 'package:jagadiri/providers/theme_provider.dart';
import 'package:jagadiri/utils/unit_converter.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jagadiri/screens/edit_sugar_reference_screen.dart';

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

  bool _isProcessing = false;

  final Map<String, Map<String, dynamic>> _exerciseFrequencyOptions = {
    'Sedentary': {
      'description': 'Little or no exercise',
      'icon': Icons.weekend,
    },
    'Light': {
      'description': 'Light exercise/sports 1-3 days/week',
      'icon': Icons.directions_walk,
    },
    'Moderate': {
      'description': 'Moderate exercise/sports 3-5 days/week',
      'icon': Icons.directions_run,
    },
    'Active': {
      'description': 'Hard exercise/sports 6-7 days a week',
      'icon': Icons.fitness_center,
    },
    'Very Active': {
      'description': 'Very hard exercise/sports & physical job',
      'icon': Icons.whatshot,
    },
  };

  final List<String> _motivationalQuotes = [
    "The last three or four reps is what makes the muscle grow. This area of pain divides a champion from someone who is not a champion.",
    "Success isn\'t always about greatness. It\'s about consistency. Consistent hard work gains success. Greatness will come.",
    "If it doesn\'t challenge you, it won\'t change you.",
  ];

  final List<String> _healthyLifestyleTips = [
    "Eat a variety of foods, including fruits, vegetables, and whole grains.",
    "Stay hydrated by drinking plenty of water throughout the day.",
    "Aim for 7-9 hours of quality sleep per night.",
  ];

  UserProfile? _userProfile;
  String _selectedThemeName = 'Light';
  String _selectedMeasurementUnit = 'Metric';
  String? _selectedGender;
  String? _selectedExerciseFrequency;
  String? _selectedSugarScenario;

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
      _dobController.text = DateFormat('dd-MM-yyyy').format(_userProfile!.dob);
      _heightController.text = _userProfile!.height.toStringAsFixed(1);
      _weightController.text = _userProfile!.weight.toStringAsFixed(1);
      _targetWeightController = TextEditingController(text: _userProfile!.targetWeight.toStringAsFixed(1));
      _selectedGender = _userProfile!.gender;
      _selectedExerciseFrequency = _userProfile!.exerciseFrequency;
      _selectedSugarScenario = _userProfile!.sugarScenario;
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
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    if (bmi < 35) return 'Obesity I';
    if (bmi < 40) return 'Obesity II';
    return 'Obesity III (Morbid)';
  }

  Future<String> _fetchOnlineAdvice() async {
    try {
      final response = await http.get(Uri.parse('https://api.quotable.io/random'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['content'];
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      throw Exception('Failed to load');
    }
  }

  Future<String> _getAdvice(UserProfile profile) async {
    String advice = '';
    try {
      advice = await _fetchOnlineAdvice();
    } catch (e) {
      final random = Random();
      advice += 'Quote: "${_motivationalQuotes[random.nextInt(_motivationalQuotes.length)]}"\n\n';
      advice += 'Tip: "${_healthyLifestyleTips[random.nextInt(_healthyLifestyleTips.length)]}"';
    }
    // ... rest of advice logic
    return advice;
  }

  int _getAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> _getSuitableSugarRange(
      int age, String measurementUnit) {
    late double min, max;
    if (age < 18) {
      min = 4.0;
      max = 7.8;
    } else {
      min = 4.0;
      max = 8.0;
    }
    if (measurementUnit == 'US') {
      min = UnitConverter.mmolToMgPerDl(min);
      max = UnitConverter.mmolToMgPerDl(max);
    }
    return {'min': min, 'max': max};
  }

  Map<String, dynamic> _getSuitableBPRange(int age) {
    if (age < 18) {
      return {'systolicMin': 90, 'systolicMax': 120, 'diastolicMin': 60, 'diastolicMax': 80};
    } else {
      return {'systolicMin': 90, 'systolicMax': 140, 'diastolicMin': 60, 'diastolicMax': 90};
    }
  }

  Map<String, dynamic> _getSuitablePulseRange(int age) {
    return {'min': 60, 'max': 100};
  }

  double _calculateDailyCalorieTarget(UserProfile profile, int age) {
    if (profile.gender == null || profile.exerciseFrequency == null) return 0;
    double weightKg = _selectedMeasurementUnit == 'Metric' ? profile.weight : UnitConverter.convertWeight(profile.weight, 'US', 'Metric');
    double heightCm = _selectedMeasurementUnit == 'Metric' ? profile.height : UnitConverter.convertHeight(profile.height, 'US', 'Metric');
    const maleOffset = 5;
    const femaleOffset = -161;
    final offset = profile.gender!.toLowerCase() == 'male' ? maleOffset : femaleOffset;
    final bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + offset;
    final multipliers = {'Sedentary': 1.2, 'Light': 1.375, 'Moderate': 1.55, 'Active': 1.725, 'Very Active': 1.9};
    final tdee = bmr * multipliers[profile.exerciseFrequency]!;
    if (profile.weight > profile.targetWeight) return tdee - 500;
    if (profile.weight < profile.targetWeight) return tdee + 300;
    return tdee;
  }

  Future<void> _saveSettings() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    await databaseService.insertSetting('themeName', _selectedThemeName);
    Provider.of<ThemeProvider>(context, listen: false).setTheme(_selectedThemeName);
    await databaseService.insertSetting('measurementUnit', _selectedMeasurementUnit);

    if (_formKey.currentState!.validate()) {
      final newProfile = UserProfile(
        id: _userProfile?.id,
        name: _nameController.text,
        dob: DateFormat('dd-MM-yyyy').parseStrict(_dobController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        targetWeight: double.parse(_targetWeightController.text),
        measurementUnit: _selectedMeasurementUnit,
        gender: _selectedGender,
        exerciseFrequency: _selectedExerciseFrequency,
        sugarScenario: _selectedSugarScenario,
      );

      final age = _getAge(newProfile.dob);
      final sugarRange = _getSuitableSugarRange(age, _selectedMeasurementUnit);
      final bpRange = _getSuitableBPRange(age);
      final pulseRange = _getSuitablePulseRange(age);
      final dailyCalories = _calculateDailyCalorieTarget(newProfile, age);

      newProfile.suitableSugarMin = sugarRange['min'];
      newProfile.suitableSugarMax = sugarRange['max'];
      newProfile.suitableSystolicMin = bpRange['systolicMin'];
      newProfile.suitableSystolicMax = bpRange['systolicMax'];
      newProfile.suitableDiastolicMin = bpRange['diastolicMin'];
      newProfile.suitableDiastolicMax = bpRange['diastolicMax'];
      newProfile.suitablePulseMin = pulseRange['min'];
      newProfile.suitablePulseMax = pulseRange['max'];
      newProfile.dailyCalorieTarget = dailyCalories;

      try {
        if (_userProfile == null) {
          await databaseService.insertUserProfile(newProfile);
        } else {
          await databaseService.updateUserProfile(newProfile);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings and Profile saved successfully!')));
        _loadSettings();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: ${e.toString()}')));
      }
    }
  }

  void _showExerciseFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Exercise Frequency'),
          children: _exerciseFrequencyOptions.keys.map((String key) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _selectedExerciseFrequency = key);
                Navigator.pop(context);
              },
              child: ListTile(
                leading: Icon(_exerciseFrequencyOptions[key]!['icon']),
                title: Text(key),
                subtitle: Text(_exerciseFrequencyOptions[key]!['description']),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showGenerateSampleDataDialog() async {
    final _formKey = GlobalKey<FormState>();
    int numRecords = 10;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Generate Sample Data'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: ListBody(
                children: <Widget>[
                  TextFormField(
                    initialValue: numRecords.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of records'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the number of records';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      numRecords = int.parse(value!);
                    },
                  ),
                  TextFormField(
                    initialValue: DateFormat('yyyy-MM-dd').format(startDate),
                    decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the start date';
                      }
                      try {
                        DateTime.parse(value);
                      } catch (e) {
                        return 'Invalid date format';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      startDate = DateTime.parse(value!);
                    },
                  ),
                  TextFormField(
                    initialValue: DateFormat('yyyy-MM-dd').format(endDate),
                    decoration: const InputDecoration(labelText: 'End date (YYYY-MM-DD)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the end date';
                      }
                      try {
                        DateTime.parse(value);
                      } catch (e) {
                        return 'Invalid date format';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      endDate = DateTime.parse(value!);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Generate'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Navigator.of(context).pop();
                  _generateSampleData(numRecords, startDate, endDate);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateSampleData(int numRecords, DateTime startDate, DateTime endDate) async {
    setState(() => _isProcessing = true);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await databaseService.generateAndInsertDummyData(numRecords, startDate, endDate);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('$numRecords sample records added successfully!')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error generating data: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteSampleData() async {
    setState(() => _isProcessing = true);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await databaseService.deleteSampleData();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('All sample data has been deleted.')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error deleting data: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'User Profile',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
                              ),
                              const SizedBox(height: 16.0),
                              TextFormField(
                                controller: _dobController,
                                readOnly: true,
                                decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                onTap: () => _selectDate(context),
                                validator: (value) => (value == null || value.isEmpty) ? 'Please select your date of birth' : null,
                              ),
                              const SizedBox(height: 16.0),
                              TextFormField(
                                controller: _heightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: 'Height (${_selectedMeasurementUnit == 'Metric' ? 'cm' : 'inches'})', border: const OutlineInputBorder()),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your height';
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Please enter a valid height';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),
                              TextFormField(
                                controller: _weightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: 'Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})', border: const OutlineInputBorder()),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your weight';
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Please enter a valid weight';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),
                              TextFormField(
                                controller: _targetWeightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: 'Target Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})', border: const OutlineInputBorder()),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your target weight';
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Please enter a valid target weight';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),
                              const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(
                                width: 300,
                                child: Column(
                                  children: [
                                    RadioListTile<String>(title: const Text('Male'), value: 'Male', groupValue: _selectedGender, secondary: const Icon(Icons.man), onChanged: (value) => setState(() => _selectedGender = value)),
                                    RadioListTile<String>(title: const Text('Female'), value: 'Female', groupValue: _selectedGender, secondary: const Icon(Icons.woman), onChanged: (value) => setState(() => _selectedGender = value)),
                                    RadioListTile<String>(title: const Text('Not Stating'), value: 'Not Stating', groupValue: _selectedGender, secondary: const Icon(Icons.not_interested), onChanged: (value) => setState(() => _selectedGender = value)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              const Text('Exercise Frequency', style: TextStyle(fontWeight: FontWeight.bold)),
                              ListTile(
                                title: Text(_selectedExerciseFrequency ?? 'Select your activity level'),
                                subtitle: _selectedExerciseFrequency != null ? Text(_exerciseFrequencyOptions[_selectedExerciseFrequency]!['description']) : null,
                                leading: _selectedExerciseFrequency != null ? Icon(_exerciseFrequencyOptions[_selectedExerciseFrequency]!['icon']) : null,
                                trailing: const Icon(Icons.arrow_drop_down),
                                onTap: () => _showExerciseFrequencyDialog(),
                              ),
                              const SizedBox(height: 16.0),
                              const Text('Diabetic Status', style: TextStyle(fontWeight: FontWeight.bold)),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSugarScenario,
                                items: ['Non-Diabetic', 'Prediabetes', 'Diabetes-ADA', 'Type 1 Diabetes', 'Type 2 Diabetes', 'Severe Hyper-glycaemia', 'Hypoglycaemia'].map((String value) {
                                  return DropdownMenuItem<String>(value: value, child: Text(value));
                                }).toList(),
                                onChanged: (String? newValue) => setState(() => _selectedSugarScenario = newValue),
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 24.0),
                              ElevatedButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save), label: const Text('Save Profile & Settings')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // App Preferences
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_applications, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'App Preferences',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        ListTile(
                          title: const Text('Theme'),
                          trailing: DropdownButton<String>(
                            value: _selectedThemeName,
                            onChanged: (String? newValue) => setState(() => _selectedThemeName = newValue!),
                            items: AppThemes.themes.keys.map((String value) {
                              return DropdownMenuItem(value: value, child: Text(value));
                            }).toList(),
                          ),
                        ),
                        ListTile(
                          title: const Text('Measurement Unit'),
                          trailing: DropdownButton<String>(
                            value: _selectedMeasurementUnit,
                            onChanged: (String? newValue) => setState(() => _selectedMeasurementUnit = newValue!),
                            items: ['Metric', 'US'].map((String value) {
                              return DropdownMenuItem(value: value, child: Text(value));
                            }).toList(),
                          ),
                        ),
                        ListTile(
                          title: const Text('Edit Sugar Reference'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditSugarReferenceScreen())),
                        ),
                      ],
                    ),
                  ),
                ),

                // Developer Tools Section
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Developer Tools',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Use these tools to manage sample data for testing and demonstration purposes.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showGenerateSampleDataDialog(),
                              icon: const Icon(Icons.add_chart),
                              label: const Text('Generate Data'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
                              onPressed: _deleteSampleData,
                              icon: const Icon(Icons.delete_sweep_outlined),
                              label: const Text('Delete Data'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Profile Summary
                if (_userProfile != null)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Summary',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          const SizedBox(height: 10.0),
                          Text('Name: ${_userProfile!.name}'),
                          Text('Age: ${_getAge(_userProfile!.dob)} years'),
                          Text('Height: ${_userProfile!.height.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'cm' : 'inches'}'),
                          Text('Weight: ${_userProfile!.weight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}'),
                          Text('Target Weight: ${_userProfile!.targetWeight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}'),
                          Text('BMI: ${_userProfile!.bmi.toStringAsFixed(1)} (${_getBMICategory(_userProfile!.bmi)})'),
                          Text('Suitable Blood Sugar Range: ' '${_userProfile!.suitableSugarMin?.toStringAsFixed(1) ?? 'N/A'} - ' '${_userProfile!.suitableSugarMax?.toStringAsFixed(1) ?? 'N/A'} ' '${_selectedMeasurementUnit == 'Metric' ? 'mmol/L' : 'mg/dL'}'),
                          Text('Suitable Blood Pressure Range: ${_userProfile!.suitableSystolicMin}-${_userProfile!.suitableSystolicMax}/${_userProfile!.suitableDiastolicMin}-${_userProfile!.suitableDiastolicMax} mmHg'),
                          Text('Suitable Pulse Range: ${_userProfile!.suitablePulseMin}-${_userProfile!.suitablePulseMax} bpm'),
                          Text('Daily Calorie Target: ${_userProfile!.dailyCalorieTarget?.toStringAsFixed(0) ?? 'N/A'} kcal'),
                          const SizedBox(height: 10.0),
                          const Text('About Your Daily Calorie Target:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Text('Your daily calorie target is an estimate of the total number of calories you burn each day (Total Daily Energy Expenditure - TDEE), adjusted based on your weight goals. It is calculated using the Mifflin-St Jeor equation, taking into account your age, gender, height, weight, and activity level.'),
                          const SizedBox(height: 10.0),
                          Text('Health Advice:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          FutureBuilder<String>(
                            future: _getAdvice(_userProfile!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                              if (snapshot.hasError) return const Text('Could not load advice.');
                              return Text(snapshot.data ?? '');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}