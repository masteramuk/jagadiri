import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart'; // Import DatabaseService
// Import UnitConverter

class SugarDataScreen extends StatefulWidget {
  const SugarDataScreen({super.key});

  @override
  State<SugarDataScreen> createState() => _SugarDataScreenState();
}

class _SugarDataScreenState extends State<SugarDataScreen> {
  List<SugarRecord> _sugarRecords = [];
  bool _isLoading = true;
  String _currentUnit = 'Metric'; // Default unit

  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _sugarValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSugarRecords();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _sugarValueController.dispose();
    super.dispose();
  }

  Future<void> _fetchSugarRecords() async {
    setState(() {
      _isLoading = true;
    });
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      _sugarRecords = await databaseService.getSugarRecords();
      _currentUnit = await databaseService.getSetting('measurementUnit') ?? 'Metric'; // Fetch unit
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sugar records from database: \${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toLocal().toString().split(' ')[0]; // Simplified date format
        debugPrint('Selected Date: \${_dateController.text}');
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final formattedTime = DateFormat.jm().format(DateTime(2023, 1, 1, picked.hour, picked.minute));
        _timeController.text = formattedTime;
        debugPrint('Selected Time: \${_timeController.text}');
      });
    }
  }

  void _addSugarRecord(MealTimeCategory? selectedMealTimeCategory, MealType? selectedMealType) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    // Validate inputs
    if (_dateController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _sugarValueController.text.isEmpty ||
        selectedMealTimeCategory == null ||
        selectedMealType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    // Parse values from controllers
    final date = DateTime.parse(_dateController.text);
    final time = DateFormat.jm().parse(_timeController.text);
    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    final sugarValue = double.tryParse(_sugarValueController.text) ?? 0.0;

    // Calculate status using the static method in SugarRecord
    final status = SugarRecord.calculateSugarStatus(
      selectedMealTimeCategory,
      sugarValue,
    );

    final newRecord = SugarRecord(
      date: date,
      time: timeOfDay,
      mealTimeCategory: selectedMealTimeCategory,
      mealType: selectedMealType,
      value: sugarValue,
      status: status,
    );

    try {
      await databaseService.insertSugarRecord(newRecord);
      // Refresh data after successful append
      _fetchSugarRecords();
      // Clear form
      _dateController.clear();
      _timeController.clear();
      _sugarValueController.clear();
      setState(() {
      });

      Navigator.of(context).pop(); // Close the form dialog
    } catch (e) {
      debugPrint('Error adding sugar record to database: \${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add record: \${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diabetes Tracker'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sugarRecords.isEmpty
              ? const Center(child: Text('No sugar records found. Add one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _sugarRecords.length,
                  itemBuilder: (context, index) {
                    final record = _sugarRecords[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date: ${record.date.toLocal().toString().split(' ')[0]} at ${record.time.format(context)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Meal: ${record.mealType.name.toUpperCase()} (${record.mealTimeCategory.name.toUpperCase()})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              'Value: ${record.value.toStringAsFixed(1)} ${_currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL'}',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Chip(
                                label: Text(record.status.name.toUpperCase()),
                                backgroundColor: record.status == SugarStatus.good
                                    ? Colors.green.shade100
                                    : record.status == SugarStatus.normal
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                labelStyle: TextStyle(
                                  color: record.status == SugarStatus.good
                                      ? Colors.green.shade800
                                      : record.status == SugarStatus.normal
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddSugarRecordForm(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSugarEntryRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '\$label:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  void _showAddSugarRecordForm(BuildContext context) {
    // Clear controllers before showing form for new entry
    _dateController.clear();
    _timeController.clear();
    _sugarValueController.clear();
    MealTimeCategory? selectedMealTimeCategory;
    MealType? selectedMealType;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Sugar Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    TextField(
                      controller: _timeController,
                      readOnly: true,
                      onTap: () => _selectTime(context),
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Meal Time Category:'),
                    Row(
                      children: MealTimeCategory.values.map((category) {
                        return Expanded(
                          child: RadioListTile<MealTimeCategory>(
                            title: Text(category.name.toUpperCase()),
                            value: category,
                            groupValue: selectedMealTimeCategory,
                            onChanged: (MealTimeCategory? value) {
                              setState(() {
                                selectedMealTimeCategory = value;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<MealType>(
                      initialValue: selectedMealType,
                      decoration: const InputDecoration(labelText: 'Meal Type'),
                      items: MealType.values.map((type) {
                        return DropdownMenuItem<MealType>(
                          value: type,
                          child: Text(type.name.split(
                                  RegExp(r'(?=[A-Z])')) // Split camelCase
                              .join(' ') // Join with space
                              .toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (MealType? newValue) {
                        setState(() {
                          selectedMealType = newValue;
                        });
                      },
                    ),
                    TextField(
                      controller: _sugarValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sugar Value'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addSugarRecord(selectedMealTimeCategory, selectedMealType),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}