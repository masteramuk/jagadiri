import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/services/database_service.dart'; // Import DatabaseService
// Import UnitConverter

class BPDataScreen extends StatefulWidget {
  const BPDataScreen({super.key});

  @override
  State<BPDataScreen> createState() => _BPDataScreenState();
}

class _BPDataScreenState extends State<BPDataScreen> {
  List<BPRecord> _bpRecords = [];
  bool _isLoading = true;
  String _currentUnit = 'Metric'; // Default unit

  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _pulseRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBPRecords();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseRateController.dispose();
    super.dispose();
  }

  Future<void> _fetchBPRecords() async {
    setState(() {
      _isLoading = true;
    });
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      _bpRecords = await databaseService.getBPRecords();
      _currentUnit = await databaseService.getSetting('measurementUnit') ?? 'Metric'; // Fetch unit
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching BP records from database: \${e.toString()}');
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

  void _addBPRecord(BPTimeName? selectedTimeName) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    // Parse values from controllers
    final date = DateTime.parse(_dateController.text);
    final time = DateFormat.jm().parse(_timeController.text);
    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    final systolic = int.tryParse(_systolicController.text) ?? 0;
    final diastolic = int.tryParse(_diastolicController.text) ?? 0;
    final pulseRate = int.tryParse(_pulseRateController.text) ?? 0;

    // Calculate status using the static method in BPRecord
    final status = BPRecord.calculateBPStatus(systolic, diastolic, pulseRate);

    final newRecord = BPRecord(
      date: date,
      time: timeOfDay,
      timeName: selectedTimeName ?? BPTimeName.morning, // Default if not selected
      systolic: systolic,
      diastolic: diastolic,
      pulseRate: pulseRate,
      status: status,
    );

    try {
      await databaseService.insertBPRecord(newRecord);
      // Refresh data after successful append
      _fetchBPRecords();
      // Clear form
      _dateController.clear();
      _timeController.clear();
      _systolicController.clear();
      _diastolicController.clear();
      _pulseRateController.clear();

      Navigator.of(context).pop(); // Close the form dialog
    } catch (e) {
      debugPrint('Error adding BP record to database: \${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add record: \${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BP & Pulse Monitor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bpRecords.isEmpty
              ? const Center(child: Text('No BP records found. Add one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _bpRecords.length,
                  itemBuilder: (context, index) {
                    final record = _bpRecords[index];
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
                            Text(
                              'Time of Day: ${record.timeName.name.toUpperCase()}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            _buildBPEntryRow('Systolic', record.systolic.toString(), 'mmHg'),
                            _buildBPEntryRow('Diastolic', record.diastolic.toString(), 'mmHg'),
                            _buildBPEntryRow('Pulse Rate', record.pulseRate.toString(), 'bpm'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Chip(
                                label: Text(record.status.name.toUpperCase()),
                                backgroundColor: record.status == BPStatus.good
                                    ? Colors.green.shade100
                                    : record.status == BPStatus.normal
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                labelStyle: TextStyle(
                                  color: record.status == BPStatus.good
                                      ? Colors.green.shade800
                                      : record.status == BPStatus.normal
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
          _showAddBPRecordForm(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBPEntryRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            '$value $unit',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  void _showAddBPRecordForm(BuildContext context) {
    // Clear controllers before showing form for new entry
    _dateController.clear();
    _timeController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _pulseRateController.clear();
    BPTimeName? selectedTimeName;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New BP Record'),
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
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return DropdownButtonFormField<BPTimeName>(
                      initialValue: selectedTimeName,
                      decoration: const InputDecoration(labelText: 'Time of Day'),
                      items: BPTimeName.values.map((BPTimeName timeName) {
                        return DropdownMenuItem<BPTimeName>(
                          value: timeName,
                          child: Text(timeName.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (BPTimeName? newValue) {
                        setState(() {
                          selectedTimeName = newValue;
                        });
                      },
                    );
                  },
                ),
                TextField(
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Systolic'),
                ),
                TextField(
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Diastolic'),
                ),
                TextField(
                  controller: _pulseRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pulse Rate'),
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
              onPressed: () => _addBPRecord(selectedTimeName),
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
  }
}
