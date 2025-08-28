import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:collection/collection.dart';

class SugarDataScreen extends StatefulWidget {
  const SugarDataScreen({super.key});

  @override
  State<SugarDataScreen> createState() => _SugarDataScreenState();
}

class _SugarDataScreenState extends State<SugarDataScreen> {
  /* -------------------- State -------------------- */
  List<SugarRecord> _sugarRecords = [];
  List<SugarRecord> _filteredSugarRecords = [];
  bool _isLoading = true;
  late String _currentUnit;

  /* ---- Cached previous record per meal type ---- */
  final Map<MealType, SugarRecord?> _previousByMeal = {};

  /* -------------------- Search -------------------- */
  final _searchStartDateController = TextEditingController();
  final _searchEndDateController = TextEditingController();
  MealType? _searchMealType;

  /* -------------------- Pagination -------------------- */
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];

  /* -------------------- Form -------------------- */
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _sugarValueController = TextEditingController();

  /* -------------------- Life-cycle -------------------- */
  @override
  void initState() {
    super.initState();
    _fetchSugarRecords();
  }

  @override
  void dispose() {
    _searchStartDateController.dispose();
    _searchEndDateController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _sugarValueController.dispose();
    super.dispose();
  }

  /* -------------------- Data fetching -------------------- */
  Future<void> _fetchSugarRecords() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      _sugarRecords = await db.getSugarRecords();
      _currentUnit = await db.getSetting('measurementUnit') ?? 'Metric';
      _buildPreviousMap();
      _filter();
    } catch (e) {
      debugPrint('Error fetching sugar records: $e');
    }
    setState(() => _isLoading = false);
  }

  /* ---- Build _previousByMeal in O(N) once ---- */
  void _buildPreviousMap() {
    _previousByMeal.clear();
    final sorted = List<SugarRecord>.from(_sugarRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final r in sorted) {
      _previousByMeal.putIfAbsent(r.mealType, () => r);
    }
  }

  /* -------------------- Filtering -------------------- */
  void _filter() {
    setState(() {
      _currentPage = 0;
      _filteredSugarRecords = _sugarRecords.where((rec) {
        final d = rec.date;
        final s = _searchStartDateController.text.isEmpty
            ? null
            : DateTime.parse(_searchStartDateController.text);
        final e = _searchEndDateController.text.isEmpty
            ? null
            : DateTime.parse(_searchEndDateController.text);

        if (s != null && d.isBefore(s)) return false;
        if (e != null && d.isAfter(e)) return false;
        if (_searchMealType != null && rec.mealType != _searchMealType) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  /* -------------------- Date / Time Pickers -------------------- */
  Future<void> _pickDate(TextEditingController ctrl) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d != null) {
      setState(() => ctrl.text = DateFormat('yyyy-MM-dd').format(d));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() => _timeController.text = t.format(context));
    }
  }

  /* -------------------- CRUD -------------------- */
  Future<void> _saveRecord(MealTimeCategory? cat, MealType? type,
      [SugarRecord? editing]) async {
    if (_dateController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _sugarValueController.text.isEmpty ||
        cat == null ||
        type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final date = DateTime.parse(_dateController.text);
    final time = TimeOfDay.fromDateTime(
        DateFormat('hh:mm a').parse(_timeController.text));
    final value = double.tryParse(_sugarValueController.text) ?? 0.0;
    final status = SugarRecord.calculateSugarStatus(cat, value);

    final record = SugarRecord(
      id: editing?.id,
      date: date,
      time: time,
      mealTimeCategory: cat,
      mealType: type,
      value: value,
      status: status,
    );

    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      editing == null
          ? await db.insertSugarRecord(record)
          : await db.updateSugarRecord(record);
      Navigator.pop(context);
      _fetchSugarRecords();
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteRecord(int id) async {
    try {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteSugarRecord(id);
      _fetchSugarRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  void _clearForm() {
    _dateController.clear();
    _timeController.clear();
    _sugarValueController.clear();
  }

  /* -------------------- UI -------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sugar Level Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _summaryCards(),
          _latestCard(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _searchCard(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _recordsTable(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /* -------------------- Widget helpers -------------------- */
  String _formatMealType(String mealType) {
    if (mealType.isEmpty) return '';
    var result = mealType.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
    return result[0].toUpperCase() + result.substring(1);
  }

  Widget _summaryCards() {
    if (_sugarRecords.isEmpty) return const SizedBox.shrink();

    final minRecord = _sugarRecords.reduce((a, b) => a.value < b.value ? a : b);
    final maxRecord = _sugarRecords.reduce((a, b) => a.value > b.value ? a : b);
    final avgValue = _sugarRecords.map((e) => e.value).reduce((a, b) => a + b) / _sugarRecords.length;
    final unit = _currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    // Trend icon logic
    IconData trendIcon = Icons.trending_flat;
    Color? trendColor;
    IconData signalIcon = Icons.horizontal_rule;
    if (_sugarRecords.length > 1) {
      final latest = _sugarRecords.first;
      final previous = _sugarRecords[1];
      if (latest.value > previous.value) {
        trendIcon = Icons.trending_up;
        trendColor = Colors.red;
        signalIcon = Icons.thumb_down;
      } else if (latest.value < previous.value) {
        trendIcon = Icons.trending_down;
        trendColor = Colors.green;
        signalIcon = Icons.thumb_up;
      } else {
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
        signalIcon = Icons.thumbs_up_down;
      }
    }


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(DateFormat('dd-MMM-yy').format(minRecord.date)),
                      const Text('Min'),
                      Text('${minRecord.value.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(DateFormat('dd-MMM-yy').format(maxRecord.date)),
                      const Text('Max'),
                      Text('${maxRecord.value.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Avg'),
                      Text('${avgValue.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(trendIcon, color: trendColor),
                      Icon(signalIcon, color: trendColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* -------------------- Latest Record (date on top, 2 icons right) -------------------- */
  Widget _latestCard() {
    if (_sugarRecords.isEmpty) return const SizedBox.shrink();
    final latest = _sugarRecords.first;
    final dt = DateTime(
      latest.date.year,
      latest.date.month,
      latest.date.day,
      latest.time.hour,
      latest.time.minute,
    );
    final unit = _currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    // Trend icon
    final prev = _previousByMeal[latest.mealType];
    IconData trendIcon = Icons.trending_flat;
    Color? trendColor;
    if (prev != null && prev != latest) {
      if (latest.value > prev.value) {
        trendIcon = Icons.trending_up;
        trendColor = Colors.red;
      } else if (latest.value < prev.value) {
        trendIcon = Icons.trending_down;
        trendColor = Colors.green;
      }
    }

    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date on top
                  Text(
                    DateFormat('dd-MMM-yyyy  hh:mm a').format(dt),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  // Meal time & type with capitalised first letters
                  Text(
                    '${_formatMealType(latest.mealTimeCategory.name)}  '
                        '${_formatMealType(latest.mealType.name)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  // Value + unit
                  Text(
                    '${latest.value.toStringAsFixed(1)} $unit',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            // Two icons on the right
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  latest.status == SugarStatus.good
                      ? Icons.thumb_up
                      : latest.status == SugarStatus.normal
                      ? Icons.thumb_up_alt_outlined
                      : Icons.thumb_down,
                  color:
                  latest.status == SugarStatus.bad ? Colors.red : Colors.green,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Icon(
                  trendIcon,
                  color: trendColor,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchStartDateController,
                    readOnly: true,
                    onTap: () => _pickDate(_searchStartDateController),
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
                    onTap: () => _pickDate(_searchEndDateController),
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Use a breakpoint to decide which button style to use
                bool useIconButtons = constraints.maxWidth < 400;

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MealType>(
                        value: _searchMealType,
                        hint: const Text('All Meal Types'),
                        items: MealType.values
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(_formatMealType(e.name)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() => _searchMealType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (useIconButtons) ...[
                      Tooltip(
                        message: 'Search',
                        child: ElevatedButton(
                          onPressed: _filter,
                          child: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reset',
                        child: ElevatedButton(
                          onPressed: () {
                            _searchStartDateController.clear();
                            _searchEndDateController.clear();
                            setState(() {
                              _searchMealType = null;
                            });
                            _filter();
                          },
                          child: const Icon(Icons.refresh),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _filter,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _searchStartDateController.clear();
                          _searchEndDateController.clear();
                          setState(() {
                            _searchMealType = null;
                          });
                          _filter();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _buildMealColumn(String header1, String header2) {
    return DataColumn(
      label: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(header1, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(header2, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  DataColumn _buildMergedHeader(String text) {
    return DataColumn(
      label: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Map<DateTime, List<SugarRecord>> _groupRecordsByDate() {
    return groupBy(_filteredSugarRecords, (SugarRecord r) => DateTime(r.date.year, r.date.month, r.date.day));
  }

  Widget _recordsTable() {
    // Group records by date, ignoring the time part.
    final groupedByDate = groupBy(
      _filteredSugarRecords,
      (SugarRecord r) => DateTime(r.date.year, r.date.month, r.date.day),
    );

    // Sort dates from newest to oldest.
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Apply pagination to the sorted dates.
    final paginatedDates = sortedDates
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    if (paginatedDates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('No records found for the selected criteria.')),
      );
    }

    // Define the meal types and time categories to create columns.
    final mealTypes = MealType.values;
    final mealTimeCategories = MealTimeCategory.values;

    // Helper to format enum names like 'midMorningSnack' into 'Mid Morning Snack'.
    String formatHeader(String name) {
      if (name.isEmpty) return '';
      var result = name.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
      return result[0].toUpperCase() + result.substring(1);
    }

    // Build the list of columns for the DataTable.
    final List<DataColumn> columns = [
      const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
      // Dynamically create a column for each combination of MealType and MealTimeCategory.
      ...mealTypes.expand((type) {
        return mealTimeCategories.map((category) {
          return DataColumn(
            label: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatHeader(type.name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(formatHeader(category.name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          );
        });
      }),
      const DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))), // Status icon
      const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))), // Actions
    ];

    // Build the list of rows from the paginated dates.
    final List<DataRow> rows = paginatedDates.map((date) {
      final recordsForDate = groupedByDate[date]!;
      
      // For efficient lookup, create a map of records for the current date.
      final recordsMap = {
        for (var r in recordsForDate) '${r.mealType.name}_${r.mealTimeCategory.name}': r
      };

      // Concatenate times if multiple records exist for the same day.
      final timesString = recordsForDate.map((r) => r.time.format(context)).join(',\n');

      // Determine the overall status for the day.
      final bool isOverallGood = recordsForDate.every((r) => r.status == SugarStatus.good || r.status == SugarStatus.normal);

      return DataRow(
        cells: [
          DataCell(Text(DateFormat('dd-MMM-yy').format(date))),
          DataCell(Text(timesString)),
          // Dynamically create a cell for each meal combination.
          ...mealTypes.expand((type) {
            return mealTimeCategories.map((category) {
              final key = '${type.name}_${category.name}';
              final record = recordsMap[key];
              return DataCell(
                Center(child: Text(record?.value.toStringAsFixed(1) ?? '')),
              );
            });
          }),
          // Status icon cell.
          DataCell(
            Center(
              child: Tooltip(
                message: isOverallGood ? 'All readings are good or normal' : 'One or more readings are high or low',
                child: Icon(
                  isOverallGood ? Icons.check_circle_outline : Icons.highlight_off,
                  color: isOverallGood ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
          // Actions cell with edit and delete buttons.
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  iconSize: 20,
                  tooltip: 'Edit Record',
                  // Editing is complex for a group, so only enable it for single-record days.
                  onPressed: recordsForDate.length == 1
                      ? () => _showFormDialog(editing: recordsForDate.first)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  iconSize: 20,
                  tooltip: 'Delete all records for this date',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: Text('Are you sure you want to delete all ${recordsForDate.length} record(s) for ${DateFormat.yMd().format(date)}?'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                              child: const Text('Delete'),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close dialog first.
                                for (var record in recordsForDate) {
                                  if (record.id != null) {
                                    _deleteRecord(record.id!);
                                  }
                                }
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        DataTable(
          columnSpacing: 12,
          horizontalMargin: 8,
          columns: columns,
          rows: rows,
        ),
        // Show pagination controls if there are more records than rows per page.
        if (sortedDates.length > _rowsPerPage)
          _pagination(sortedDates.length),
      ],
    );
  }

  Widget _pagination(int totalRows) {
    final totalPages = (totalRows / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
        ),
        Text('Page ${_currentPage + 1} of $totalPages'),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _currentPage < totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
        ),
        DropdownButton<int>(
          value: _rowsPerPage,
          items: _rowsPerPageOptions
              .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
              .toList(),
          onChanged: (v) => setState(() {
            _rowsPerPage = v!;
            _currentPage = 0;
          }),
        ),
      ],
    );
  }

  /* -------------------- Form dialog -------------------- */
  void _showFormDialog({SugarRecord? editing}) {
    if (editing == null) _clearForm();
    _dateController.text = editing?.date
        .toIso8601String()
        .split('T')
        .first ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _timeController.text = editing?.time.format(context) ?? '';
    _sugarValueController.text = editing?.value.toString() ?? '';

    MealTimeCategory? cat = editing?.mealTimeCategory ?? MealTimeCategory.before;
    MealType? type = editing?.mealType ?? MealType.breakfast;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState2) => AlertDialog(
          title: Text(editing == null ? 'Add Record' : 'Edit Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Date', suffixIcon: Icon(Icons.calendar_today)),
                  onTap: () => _pickDate(_dateController),
                ),
                TextField(
                  controller: _timeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Time', suffixIcon: Icon(Icons.access_time)),
                  onTap: _pickTime,
                ),
                DropdownButtonFormField<MealTimeCategory>(
                  value: cat,
                  items: MealTimeCategory.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(_formatMealType(e.name))))
                      .toList(),
                  onChanged: (v) => setState2(() => cat = v),
                  decoration: const InputDecoration(labelText: 'Meal Time'),
                ),
                DropdownButtonFormField<MealType>(
                  value: type,
                  items: MealType.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(_formatMealType(e.name))))
                      .toList(),
                  onChanged: (v) => setState2(() => type = v),
                  decoration: const InputDecoration(labelText: 'Meal Type'),
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
                onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _saveRecord(cat, type, editing),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}