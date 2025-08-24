import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart';

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
        DateFormat.jm().parse(_timeController.text));
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
  Widget _summaryCards() {
    if (_filteredSugarRecords.isEmpty) return const SizedBox.shrink();
    final min = _filteredSugarRecords
        .reduce((a, b) => a.value < b.value ? a : b);
    final max = _filteredSugarRecords
        .reduce((a, b) => a.value > b.value ? a : b);
    final avg = _filteredSugarRecords
        .map((e) => e.value)
        .reduce((a, b) => a + b) /
        _filteredSugarRecords.length;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryTile('Min', min.value, min.date),
          _summaryTile('Max', max.value, max.date),
          _summaryTile('Avg', avg, null),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double value, DateTime? date) {
    return Column(
      children: [
        if (date != null) Text(DateFormat.yMd().format(date)),
        Text(label),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
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
                    '${latest.mealTimeCategory.name[0].toUpperCase()}${latest.mealTimeCategory.name.substring(1).toLowerCase()}  '
                        '${latest.mealType.name[0].toUpperCase()}${latest.mealType.name.substring(1).toLowerCase()}',
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
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
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
            DropdownButtonFormField<MealType>(
              value: _searchMealType,
              hint: const Text('All Meal Types'),
              items: MealType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (val) {
                setState(() => _searchMealType = val);
                _filter();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _filter, child: const Text('Search')),
                ElevatedButton(
                    onPressed: () {
                      _searchStartDateController.clear();
                      _searchEndDateController.clear();
                      _searchMealType = null;
                      _filter();
                    },
                    child: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsTable() {
    final rows = _filteredSugarRecords
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();
    if (rows.isEmpty) return const Text('No records');
    final unit = _currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    return Column(
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Meal')),
            DataColumn(label: Text('Value')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            return DataRow(
              color: MaterialStateProperty.all(
                  r.status == SugarStatus.bad ? Colors.red.shade100 : null),
              cells: [
                DataCell(Text(DateFormat.yMd().format(r.date))),
                DataCell(Text(r.time.format(context))),
                DataCell(Text(r.mealType.name)),
                DataCell(Text('${r.value.toStringAsFixed(1)} $unit')),
                DataCell(Text(r.status.name)),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showFormDialog(editing: r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteRecord(r.id!),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
        _pagination(),
      ],
    );
  }

  Widget _pagination() {
    final total = _filteredSugarRecords.length;
    final pages = (total / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
        ),
        Text('Page ${_currentPage + 1} of $pages'),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _currentPage < pages - 1
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
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState2(() => cat = v),
                  decoration: const InputDecoration(labelText: 'Meal Time'),
                ),
                DropdownButtonFormField<MealType>(
                  value: type,
                  items: MealType.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
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