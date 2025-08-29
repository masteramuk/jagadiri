import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
} // End of ProfileSettingsScreen class

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;

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
    "Success isn't always about greatness. It's about consistency. Consistent hard work gains success. Greatness will come.",
    "If it doesn't challenge you, it won't change you.",
    "The only bad workout is the one that didn't happen.",
    "You don't have to be extreme. Just consistent.",
    "A little progress each day adds up to big results.",
    "Take care of your body. It's the only place you have to live.",
    "A healthy outside starts from the inside.",
    "Believe you can, and you're halfway there.",
    "Your body hears everything your mind says.",
    "The body achieves what the mind believes.",
  ];

  final List<String> _healthyLifestyleTips = [
    "Eat a variety of foods, including fruits, vegetables, and whole grains.",
    "Base your meals on high-fiber carbohydrates like potatoes, bread, rice, and pasta.",
    "Choose healthy fats from sources like avocados, nuts, and olive oil.",
    "Limit your intake of sugar and salt.",
    "Stay hydrated by drinking plenty of water throughout the day.",
    "Start slowly with exercise and gradually increase the intensity and duration.",
    "Find physical activities you enjoy to make your routine more sustainable.",
    "Incorporate strength training into your routine at least twice a week.",
    "Listen to your body and take rest days when you need them.",
    "Connect with others to improve your mental well-being.",
    "Aim for 7-9 hours of quality sleep per night.",
    "Practice mindfulness to reduce stress and improve self-awareness.",
  ];

  UserProfile? _userProfile;
  String _selectedThemeName = 'Light';
  String _selectedMeasurementUnit = 'Metric';
  String? _selectedGender;
  String? _selectedExerciseFrequency;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _targetWeightController = TextEditingController();
    _loadSettings();
  } // End of initState method

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  } // End of dispose method

  Future<void> _loadSettings() async {
    final databaseService =
    Provider.of<DatabaseService>(context, listen: false);
    _userProfile = await databaseService.getUserProfile();
    _selectedThemeName =
        await databaseService.getSetting('themeName') ?? 'Light';
    _selectedMeasurementUnit =
        await databaseService.getSetting('measurementUnit') ?? 'Metric';

    if (_userProfile != null) {
      _nameController.text = _userProfile!.name;
      _dobController.text = DateFormat('dd-MM-yyyy').format(_userProfile!.dob);
      _heightController.text = _userProfile!.height.toStringAsFixed(1);
      _weightController.text = _userProfile!.weight.toStringAsFixed(1);
      _targetWeightController.text =
          _userProfile!.targetWeight.toStringAsFixed(1);
      _selectedGender = _userProfile!.gender;
      _selectedExerciseFrequency = _userProfile!.exerciseFrequency;
    }
    setState(() {});
  }// End of _loadSettings method

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
  }// End of _selectDate method

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    if (bmi < 35) return 'Obesity I';
    if (bmi < 40) return 'Obesity II';
    return 'Obesity III (Morbid)'; // bmi ≥ 40
  } // End of _getBMICategory method

  Future<String> _fetchOnlineAdvice() async {
    try {
      // I will use a placeholder that returns a simple string.
      // In a real application, this would be a call to a real API.
      final response = await http.get(Uri.parse('https://api.quotable.io/random'));
      if (response.statusCode == 200) {
        // a simple api that returns a json with a quote
        final data = json.decode(response.body);
        return data['content'];
      } else {
        throw Exception('Failed to load online advice');
      }
    } catch (e) {
      throw Exception('Failed to load online advice');
    }
  }

  Future<String> _getAdvice(UserProfile profile) async {
    String advice = '';
    try {
      advice = await _fetchOnlineAdvice();
    } catch (e) {
      // Fallback to local lists
      final random = Random();
      advice += 'Quote of the day: "${_motivationalQuotes[random.nextInt(_motivationalQuotes.length)]}"\n\n';
      advice += 'Tip of the day: "${_healthyLifestyleTips[random.nextInt(_healthyLifestyleTips.length)]}"';
    }

    String baseAdvice = '';
    if (profile.bmi < 18.5) {
      baseAdvice =
      'You are underweight. Consider consulting a doctor or nutritionist to gain weight healthily.\n\n';
    } else if (profile.bmi >= 25) {
      baseAdvice =
      'You are overweight or obese. Focus on a calorie-controlled diet and increased physical activity.\n\n';
    }

    if (profile.weight > profile.targetWeight) {
      baseAdvice +=
      'You are currently above your target weight. Focus on gradual weight loss.\n\n';
    } else if (profile.weight < profile.targetWeight) {
      baseAdvice += 
      'You are currently below your target weight. Ensure healthy weight gain if that is your goal.\n\n';
    } else {
      baseAdvice += 
      'You are at your target weight. Great job! Maintain your healthy habits.\n\n';
    }

    return baseAdvice + advice;
  } // End of _getAdvice method

  int _getAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {age--;};
    return age;
  } // End of _getAge method

  /// Always returns the correct unit based on the user’s choice.
  Map<String, dynamic> _getSuitableSugarRange(
      int age, String measurementUnit) {
    // Base values in mmol/L
    late double min, max;
    if (age < 18) {
      min = 4.0;
      max = 7.8;
    } else if (age <= 60) {
      min = 4.0;
      max = 7.8;
    } else {
      min = 4.4;
      max = 8.0;
    }

    // Convert if the user picked US units
    if (measurementUnit == 'US') {
      min *= 18.0182;
      max *= 18.0182;
    }

    return {'min': min, 'max': max};
  } // End of _getSuitableSugarRange method

  Map<String, dynamic> _getSuitableBPRange(int age) {
    if (age < 18) {
      return {
        'systolicMin': 90,
        'systolicMax': 120,
        'diastolicMin': 60,
        'diastolicMax': 80
      };
    } else if (age <= 60) {
      return {
        'systolicMin': 90,
        'systolicMax': 120,
        'diastolicMin': 60,
        'diastolicMax': 80
      };
    } else {
      return {
        'systolicMin': 110,
        'systolicMax': 140,
        'diastolicMin': 70,
        'diastolicMax': 90
      };
    }
  } // End of _getSuitableBPRange method

  Map<String, dynamic> _getSuitablePulseRange(int age) {
    return {'min': 60, 'max': 100}; // bpm
  } // End of _getSuitablePulseRange method

  double _calculateDailyCalorieTarget(UserProfile profile, int age) {
    if (profile.gender == null || profile.exerciseFrequency == null) {
      return 0; // Or some default value, or handle the error appropriately
    }

    double weightKg = profile.measurementUnit == 'Metric'
        ? profile.weight
        : UnitConverter.convertWeight(profile.weight, 'US', 'Metric');
    double heightCm = profile.measurementUnit == 'Metric'
        ? profile.height
        : UnitConverter.convertHeight(profile.height, 'US', 'Metric');

    // Mifflin-St Jeor Equation
    const maleOffset = 5;
    const femaleOffset = -161;
    final offset = profile.gender!.toLowerCase() == 'male' ? maleOffset : femaleOffset;

    final bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + offset;

    // Activity multipliers
    final multipliers = {
      'Sedentary': 1.2,
      'Light': 1.375,
      'Moderate': 1.55,
      'Active': 1.725,
      'Very Active': 1.9,
    };

    final tdee = bmr * multipliers[profile.exerciseFrequency]!;

    // Adjustment for target weight
    if (profile.weight > profile.targetWeight) {
      return tdee - 500; // ~0.5 kg loss/week
    } else if (profile.weight < profile.targetWeight) {
      return tdee + 300; // ~0.3 kg gain/week
    }
    return tdee;
  } // End of _calculateDailyCalorieTarget method

  Future<void> _saveSettings() async {
    final databaseService =
    Provider.of<DatabaseService>(context, listen: false);

    await databaseService.insertSetting('themeName', _selectedThemeName);
    Provider.of<ThemeProvider>(context, listen: false)
        .setTheme(_selectedThemeName);

    await databaseService.insertSetting(
        'measurementUnit', _selectedMeasurementUnit);

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Settings and Profile saved successfully!')),
        );
        _loadSettings();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    }
  }// End of _saveSettings method

  void _showExerciseFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Exercise Frequency'),
          children: _exerciseFrequencyOptions.keys.map((String key) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _selectedExerciseFrequency = key;
                });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Profile & Settings')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                      style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    ),// End of Text
                                  ], //end of children of Row
                              ), // End of Row
                              const Divider(),
                              ListTile(
                                title: const Text('Theme'),
                                trailing: DropdownButton<String>(
                                  value: _selectedThemeName,
                                  onChanged: (String? newValue) {
                                    setState(() => _selectedThemeName = newValue!);
                                  },
                                  items: AppThemes.themes.keys.map((String value) {
                                    return DropdownMenuItem(
                                        value: value, child: Text(value));
                                  }).toList(),
                                ),// End of DropdownButton
                              ),// End of ListTile
                              ListTile(
                                title: const Text('Measurement Unit'),
                                trailing: DropdownButton<String>(
                                  value: _selectedMeasurementUnit,
                                  onChanged: (String? newValue) {
                                    setState(() => _selectedMeasurementUnit = newValue!);
                                  },
                                  items: ['Metric', 'US'].map((String value) {
                                    return DropdownMenuItem(
                                        value: value, child: Text(value));
                                  }).toList(),
                                ),// End of DropdownButton
                              ), // End of ListTile
                              ListTile(
                                title: const Text('Edit Sugar Reference'),
                                trailing: const Icon(Icons.edit),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const EditSugarReferenceScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],// End of children of Column
                        ), //end of Column
                      ), // End of Padding
                    ),// end of Card() App Preferences
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),// End of Text
                              ], // End of children of Row
                            ), // End of Row
                            const Divider(),
                            //start FORM
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ), // End of TextFormField for Name
                                  const SizedBox(height: 16.0),
                                  TextFormField(
                                    controller: _dobController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Date of Birth',
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    onTap: () => _selectDate(context),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select your date of birth';
                                      }
                                      return null;
                                    },
                                  ), // End of TextFormField for DOB
                                  const SizedBox(height: 16.0),
                                  TextFormField(
                                    controller: _heightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Height (${_selectedMeasurementUnit == 'Metric' ? 'cm' : 'inches'})',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your height';
                                      }
                                      final height = double.tryParse(value);
                                      if (height == null || height <= 0) {
                                        return 'Please enter a valid height';
                                      }
                                      return null;
                                    },
                                  ), // End of TextFormField for Height
                                  const SizedBox(height: 16.0),
                                  TextFormField(
                                    controller: _weightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your weight';
                                      }
                                      final weight = double.tryParse(value);
                                      if (weight == null || weight <= 0) {
                                        return 'Please enter a valid weight';
                                      }
                                      return null;
                                    },
                                  ), // End of TextFormField for Weight
                                  const SizedBox(height: 16.0),
                                  TextFormField(
                                    controller: _targetWeightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Target Weight (${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'})',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your target weight';
                                      }
                                      final targetWeight = double.tryParse(value);
                                      if (targetWeight == null || targetWeight <= 0) {
                                        return 'Please enter a valid target weight';
                                      }
                                      return null;
                                    },
                                  ), // End of TextFormField for Target Weight
                                  const SizedBox(height: 16.0),
                                  const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(
                                    width: 300,
                                    child: Column(
                                      children: [
                                        RadioListTile<String>(
                                          title: const Text('Male'),
                                          value: 'Male',
                                          groupValue: _selectedGender,
                                          secondary: const Icon(Icons.man),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                        ),
                                        RadioListTile<String>(
                                          title: const Text('Female'),
                                          value: 'Female',
                                          groupValue: _selectedGender,
                                          secondary: const Icon(Icons.woman),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                        ),
                                        RadioListTile<String>(
                                          title: const Text('Not Stating'),
                                          value: 'Not Stating',
                                          groupValue: _selectedGender,
                                          secondary: const Icon(Icons.not_interested),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),
                                  const Text('Exercise Frequency', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ListTile(
                                    title: Text(_selectedExerciseFrequency ?? 'Select your activity level'),
                                    subtitle: _selectedExerciseFrequency != null
                                        ? Text(_exerciseFrequencyOptions[_selectedExerciseFrequency]!['description'])
                                        : null,
                                    leading: _selectedExerciseFrequency != null
                                        ? Icon(_exerciseFrequencyOptions[_selectedExerciseFrequency]!['icon'])
                                        : null,
                                    trailing: const Icon(Icons.arrow_drop_down),
                                    onTap: () => _showExerciseFrequencyDialog(),
                                  ),
                                  const SizedBox(height: 24.0),
                                  ElevatedButton.icon(
                                    onPressed: _saveSettings,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save Profile & Settings'),
                                  ), // End of ElevatedButton
                                ], // End of children of Column in FORM
                              ), // End of Column in FORM
                            ),
                            //end FORM
                            const SizedBox(height: 20.0),
                            if (_userProfile != null) ...[
                              const Divider(),
                              Text(
                                'Profile Summary',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10.0),
                              Text('Name: ${_userProfile!.name}'),
                              Text(
                                'Age: ${_getAge(_userProfile!.dob)} years',
                              ),
                              Text(
                                'Height: ${_userProfile!.height.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'cm' : 'inches'}',
                              ),
                              Text(
                                'Weight: ${_userProfile!.weight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}',
                              ),
                              Text(
                                'Target Weight: ${_userProfile!.targetWeight.toStringAsFixed(1)} ${_selectedMeasurementUnit == 'Metric' ? 'kg' : 'lbs'}',
                              ),
                              Text(
                                'BMI: ${_userProfile!.bmi.toStringAsFixed(1)} (${_getBMICategory(_userProfile!.bmi)})',
                              ),
                              Text(
                                'Suitable Blood Sugar Range: '
                                    '${_userProfile!.suitableSugarMin?.toStringAsFixed(1) ?? 'N/A'} - '
                                    '${_userProfile!.suitableSugarMax?.toStringAsFixed(1) ?? 'N/A'} '
                                    '${_selectedMeasurementUnit == 'Metric' ? 'mmol/L' : 'mg/dL'}',
                              ),
                              Text(
                                'Suitable Blood Pressure Range: ${_userProfile!.suitableSystolicMin}-${_userProfile!.suitableSystolicMax}/${_userProfile!.suitableDiastolicMin}-${_userProfile!.suitableDiastolicMax} mmHg',
                              ),
                              Text(
                                'Suitable Pulse Range: ${_userProfile!.suitablePulseMin}-${_userProfile!.suitablePulseMax} bpm',
                              ),
                              Text(
                                'Daily Calorie Target: ${_userProfile!.dailyCalorieTarget?.toStringAsFixed(0) ?? 'N/A'} kcal',
                              ),
                              const SizedBox(height: 10.0),
                              const Text(
                                'About Your Daily Calorie Target:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Your daily calorie target is an estimate of the total number of calories you burn each day (Total Daily Energy Expenditure - TDEE), adjusted based on your weight goals. It is calculated using the Mifflin-St Jeor equation, taking into account your age, gender, height, weight, and activity level.',
                              ),
                              const SizedBox(height: 10.0),
                              Text(
                                'Health Advice:',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              FutureBuilder<String>(
                                future: _getAdvice(_userProfile!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    return const Text('Could not load advice.');
                                  } else {
                                    return Text(snapshot.data ?? '');
                                  }
                                },
                              ),
                            ], // End of if _userProfile != null
                          ], // End of children of Column
                      ), // End of Padding
                    ), // End of Padding
                  ) //end of Card() User Profile
                ], // End of children of Column
            ) // End of Column
        )// End of SingleChildScrollView
    ); // End of Scaffold
  } // End of build method

} // End of _ProfileSettingsScreenState class