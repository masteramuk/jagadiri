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
  List<SugarRecord> _filteredSugarRecords = [];
  bool _isLoading = true;
  String _currentUnit = 'Metric'; // Default unit

  // Search controllers
  final TextEditingController _searchStartDateController = TextEditingController();
  final TextEditingController _searchEndDateController = TextEditingController();
  MealType? _searchMealType;

  // Pagination
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];

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
      _filterSugarRecords();
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

  void _filterSugarRecords() {
    setState(() {
      _filteredSugarRecords = _sugarRecords.where((record) {
        final recordDate = record.date;
        final startDate = _searchStartDateController.text.isNotEmpty
            ? DateTime.parse(_searchStartDateController.text)
            : null;
        final endDate = _searchEndDateController.text.isNotEmpty
            ? DateTime.parse(_searchEndDateController.text)
            : null;

        if (startDate != null && recordDate.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && recordDate.isAfter(endDate)) {
          return false;
        }
        if (_searchMealType != null && record.mealType != _searchMealType) {
          return false;
        }
        return true;
      }).toList();
    });
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

  void _saveSugarRecord(MealTimeCategory? selectedMealTimeCategory, MealType? selectedMealType, [SugarRecord? record]) async {
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
      id: record?.id,
      date: date,
      time: timeOfDay,
      mealTimeCategory: selectedMealTimeCategory,
      mealType: selectedMealType,
      value: sugarValue,
      status: status,
    );

    try {
      if (record == null) {
        await databaseService.insertSugarRecord(newRecord);
      } else {
        await databaseService.updateSugarRecord(newRecord);
      }
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

  Future<void> _deleteSugarRecord(int id) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    try {
      await databaseService.deleteSugarRecord(id);
      _fetchSugarRecords();
    } catch (e) {
      debugPrint('Error deleting sugar record from database: \${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete record: \${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugar Level Tracker'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryAndLatestRecordCards(),
                _buildLatestRecordCard(),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 600), // Adjust as needed
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSearchCard(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildRecordsTable(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddSugarRecordForm(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryAndLatestRecordCards() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildSummaryCards(),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchStartDateController,
                    readOnly: true,
                    onTap: () => _selectSearchDate(context, _searchStartDateController),
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchEndDateController,
                    readOnly: true,
                    onTap: () => _selectSearchDate(context, _searchEndDateController),
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MealType>(
              value: _searchMealType,
              decoration: const InputDecoration(labelText: 'Meal Type'),
              items: MealType.values.map((type) {
                return DropdownMenuItem<MealType>(
                  value: type,
                  child: Text(type.name.split(RegExp(r'(?=[A-Z])')).join(' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (MealType? newValue) {
                setState(() {
                  _searchMealType = newValue;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _filterSugarRecords,
                  child: const Text('Search'),
                ),
                ElevatedButton(
                  onPressed: _resetSearch,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetSearch() {
    setState(() {
      _searchStartDateController.clear();
      _searchEndDateController.clear();
      _searchMealType = null;
      _filterSugarRecords();
    });
  }

  Future<void> _selectSearchDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  Widget _buildSummaryCards() {
    if (_filteredSugarRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final SugarRecord minRecord = _filteredSugarRecords.reduce((a, b) => a.value < b.value ? a : b);
    final SugarRecord maxRecord = _filteredSugarRecords.reduce((a, b) => a.value > b.value ? a : b);
    final double avgValue = _filteredSugarRecords.map((e) => e.value).reduce((a, b) => a + b) / _filteredSugarRecords.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryCard('Min', minRecord.value, DateFormat.yMd().format(minRecord.date), Icons.arrow_downward, Colors.green),
        _buildSummaryCard('Max', maxRecord.value, DateFormat.yMd().format(maxRecord.date), Icons.arrow_upward, Colors.red),
        _buildSummaryCard('Avg', avgValue, '', Icons.trending_flat, Colors.blue),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double value, String date, IconData icon, Color color) {
    return Column(
      children: [
        Text(date, style: const TextStyle(fontSize: 12)),
        Icon(icon, color: color),
        Text(title),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildLatestRecordCard() {
    if (_sugarRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestRecord = _sugarRecords.first;
    final dateTime = latestRecord.date.add(Duration(hours: latestRecord.time.hour, minutes: latestRecord.time.minute));
    final formattedDate = DateFormat('dd-MMM-yyyy hh:mm a').format(dateTime);

    final mealTypeString = latestRecord.mealType.name.split(RegExp(r'(?=[A-Z])')).join(' ');
    final subtitle = _capitalizeWords('${latestRecord.mealTimeCategory.name} $mealTypeString');

    final trendIcon = _getTrendIcon(latestRecord);
    final statusIcon = _getStatusIcon(latestRecord.status);
    final unit = _currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedDate, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${latestRecord.value.toStringAsFixed(1)} $unit', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            Column(
              children: [
                statusIcon,
                const SizedBox(height: 8),
                trendIcon,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Icon _getStatusIcon(SugarStatus status) {
    switch (status) {
      case SugarStatus.good:
        return const Icon(Icons.thumb_up, color: Colors.green, size: 40);
      case SugarStatus.normal:
        return const Icon(Icons.thumb_up_alt_outlined, color: Colors.blue, size: 40);
      case SugarStatus.bad:
        return const Icon(Icons.thumb_down, color: Colors.red, size: 40);
    }
  }

  Icon _getTrendIcon(SugarRecord latestRecord) {
    final relevantRecords = _sugarRecords.where((record) => record.mealType == latestRecord.mealType).toList();
    if (relevantRecords.length < 2) {
      return const Icon(Icons.trending_flat, size: 40);
    }

    final previousRecord = relevantRecords[1];
    if (latestRecord.value > previousRecord.value) {
      return const Icon(Icons.trending_up, color: Colors.red, size: 40);
    } else if (latestRecord.value < previousRecord.value) {
      return const Icon(Icons.trending_down, color: Colors.green, size: 40);
    } else {
      return const Icon(Icons.trending_flat, size: 40);
    }
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

  void _showAddSugarRecordForm(BuildContext context, {SugarRecord? record}) {
    // Clear controllers before showing form for new entry
    if (record == null) {
      _dateController.clear();
      _timeController.clear();
      _sugarValueController.clear();
    } else {
      _dateController.text = record.date.toLocal().toString().split(' ')[0];
      _timeController.text = record.time.format(context);
      _sugarValueController.text = record.value.toString();
    }

    MealTimeCategory? selectedMealTimeCategory = record?.mealTimeCategory ?? MealTimeCategory.before;
    MealType? selectedMealType = record?.mealType ?? MealType.breakfast;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(record == null ? 'Add New Sugar Record' : 'Edit Sugar Record'),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: MealTimeCategory.values.map((category) {
                        return SizedBox(
                          width: 200,
                          child: RadioListTile<MealTimeCategory>(
                            title: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(category.name.toUpperCase()),
                            ),
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
                  onPressed: () => _saveSugarRecord(selectedMealTimeCategory, selectedMealType, record),
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

  Widget _buildRecordsTable() {
    if (_filteredSugarRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final paginatedRecords = _filteredSugarRecords
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Column(
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Meal Type')),
            DataColumn(label: Text('Value')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: paginatedRecords.map((record) {
            return DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                if (record.status == SugarStatus.bad) {
                  return Colors.red.shade100;
                }
                return null; // Use the default color.
              }),
              cells: [
                DataCell(Text(DateFormat.yMd().format(record.date))),
                DataCell(Text(record.time.format(context))),
                DataCell(Text(record.mealType.name)),
                DataCell(Text(record.value.toStringAsFixed(1))),
                DataCell(Text(record.status.name)),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _showAddSugarRecordForm(context, record: record);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteSugarRecord(record.id!);
                      },
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final int totalRecords = _filteredSugarRecords.length;
    final int totalPages = (totalRecords / _rowsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentPage > 0
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
        ),
        Text('Page ${_currentPage + 1} of $totalPages'),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _currentPage < totalPages - 1
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
        ),
        const SizedBox(width: 20),
        DropdownButton<int>(
          value: _rowsPerPage,
          items: _rowsPerPageOptions.map((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text('$value rows'),
            );
          }).toList(),
          onChanged: (int? newValue) {
            setState(() {
              _rowsPerPage = newValue!;
              _currentPage = 0;
            });
          },
        ),
      ],
    );
  }
}