import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:collection/collection.dart';

import 'package:jagadiri/providers/user_profile_provider.dart';
import 'package:jagadiri/utils/sugar_analysis.dart';

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
  bool _isLatestCardExpanded = false;
  bool _isSearchCardExpanded = false;

  /* ---- Cached previous record per meal type ---- */
  final Map<MealType, SugarRecord?> _previousByMeal = {};

  /* -------------------- Search -------------------- */
  final _searchStartDateController = TextEditingController();
  final _searchEndDateController = TextEditingController();
  MealType? _searchMealType;

  /* -------------------- Pagination -------------------- */
  int _currentPage = 0;
  int _rowsPerPage = 5;
  final List<int> _rowsPerPageOptions = [5, 10, 20, 50, 100];

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
            : DateFormat('dd-MMM-yyyy').parse(_searchStartDateController.text);
        final e = _searchEndDateController.text.isEmpty
            ? null
            : DateFormat('dd-MMM-yyyy').parse(_searchEndDateController.text);

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
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365 * 100)), // −100 years
      lastDate: now.add(const Duration(days: 365 * 100)),      // +100 years
    );
    if (d != null) {
      setState(() => ctrl.text = DateFormat('dd-MMM-yyyy').format(d));
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

    final date = DateFormat('dd-MMM-yyyy').parse(_dateController.text);
    final time = TimeOfDay.fromDateTime(
        DateFormat('hh:mm a').parse(_timeController.text));
    final value = double.tryParse(_sugarValueController.text) ?? 0.0;
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final userDiabetesType = userProfileProvider.userProfile?.sugarScenario ?? 'non-diabetic';

    final status = await analyseStatus(
      records: [
        SugarRecord(
          date: date,
          time: time,
          mealTimeCategory: cat,
          mealType: type,
          value: value,
          status: SugarStatus.good, // temporary status
        )
      ],
      unit: _currentUnit,
      userDiabetesType: userDiabetesType,
    );

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
    final theme = Theme.of(context);

    // Group records by date to calculate total rows for pagination
    final groupedByDate = groupBy(
      _filteredSugarRecords,
      (SugarRecord r) => DateTime(r.date.year, r.date.month, r.date.day),
    );
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Sugar Level Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _summaryCards(),
                  _buildExpandableCard(
                    title: 'Latest Record',
                    content: _latestCard(),
                    isExpanded: _isLatestCardExpanded,
                    onToggle: () {
                      setState(() {
                        _isLatestCardExpanded = !_isLatestCardExpanded;
                      });
                    },
                  ),
                  _buildExpandableCard(
                    title: 'Search',
                    content: _searchCard(),
                    isExpanded: _isSearchCardExpanded,
                    onToggle: () {
                      setState(() {
                        _isSearchCardExpanded = !_isSearchCardExpanded;
                      });
                    },
                  ),
                  _recordsTable(theme, groupedByDate, sortedDates),
                  _pagination(sortedDates.length),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /* -------------------- Widget helpers -------------------- */
  Widget _buildExpandableCard({
    required String title,
    required Widget content,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
                title,
                style: Theme. of(context).textTheme.titleMedium,
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onPressed: onToggle,
            ),
            onTap: onToggle, // Allow tapping the tile to toggle
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: content,
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /* Capitalise first letter and add spaces before capitals */
  String _formatMealType(String mealType) {
    if (mealType.isEmpty) return '';
    var result = mealType.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
    return result[0].toUpperCase() + result.substring(1);
  }

  /* -------------------- Summary Cards (Min, Max, Avg, Trend) -------------------- */
  Widget _summaryCards() {
    if (_filteredSugarRecords.isEmpty) {
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
                      children: const [
                        Text('-'),
                        Text('Min'),
                        Text('NA', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      children: const [
                        Text('-'),
                        Text('Max'),
                        Text('NA', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      children: const [
                        Text('Avg'),
                        Text('NA', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      children: const [
                        Icon(Icons.trending_flat, color: Colors.grey),
                        Icon(Icons.horizontal_rule, color: Colors.grey),
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

    final minRecord = _filteredSugarRecords.reduce((a, b) => a.value < b.value ? a : b);
    final maxRecord = _filteredSugarRecords.reduce((a, b) => a.value > b.value ? a : b);
    final avgValue = _filteredSugarRecords.map((e) => e.value).reduce((a, b) => a + b) / _filteredSugarRecords.length;
    final unit = _currentUnit == 'Metric' ? 'mmol/L' : 'mg/dL';

    // Trend icon logic
    IconData trendIcon = Icons.trending_flat;
    Color? trendColor;
    IconData signalIcon = Icons.horizontal_rule;
    if (_filteredSugarRecords.length > 1) {
      final latest = _filteredSugarRecords.first;
      final previous = _filteredSugarRecords[1];
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

    /* -------------------- Cards Layout -------------------- */
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

    return Row(
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
                  : latest.status == SugarStatus.low
                  ? Icons.thumb_down
                  : Icons.thumb_down,
              color:
              latest.status == SugarStatus.good ? Colors.green : Colors.red,
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
    );
  }

  Widget _searchCard() {
    return Column(
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
    );
  }

  /*
  Widget _recordsTable(ThemeData theme, Map<DateTime, List<SugarRecord>> groupedByDate, List<DateTime> sortedDates) {
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

    DataColumn _buildStyledHeader(String main, {String sub = ''}) {
      return DataColumn(
        label: Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(main, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary), textAlign: TextAlign.center), 
                if (sub.isNotEmpty)
                  Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    String formatHeader(String name) {
      if (name.isEmpty) return '';
      var result = name.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
      return result[0].toUpperCase() + result.substring(1);
    }

    final List<DataColumn> columns = [
      _buildStyledHeader('Date'),
      _buildStyledHeader('Time'),
    ];
    for (var type in MealType.values) {
      columns.add(_buildStyledHeader(formatHeader(type.name), sub: 'Before'));
      columns.add(_buildStyledHeader('', sub: 'After'));
    }
    columns.addAll([_buildStyledHeader('Status'), _buildStyledHeader('Actions')]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.resolveWith((states) => theme.primaryColor),
        border: TableBorder.all(color: theme.dividerColor, width: 1),
        columns: columns,
        rows: paginatedDates.map((date) {
          final recordsForDate = groupedByDate[date]!;
          final timesString = recordsForDate.map((r) => r.time.format(context)).join(',\n');
          final recordsMap = {for (var r in recordsForDate) '${r.mealType.name}_${r.mealTimeCategory.name}': r};

          final List<DataCell> cells = [
            DataCell(Center(child: Text(DateFormat('dd-MMM-yy').format(date)))),
            DataCell(Center(child: Text(timesString))),
          ];

          for (var type in MealType.values) {
            for (var category in MealTimeCategory.values) {
              final key = '${type.name}_${category.name}';
              final record = recordsMap[key];
              cells.add(DataCell(Center(child: FittedBox(child: Text(record?.value.toStringAsFixed(1) ?? '')))));
            }
          }

          cells.addAll([
            DataCell(Center(child: Tooltip(message: recordsForDate.first.status.name, child: Icon(recordsForDate.first.status == SugarStatus.good ? Icons.check_circle_outline : Icons.highlight_off, color: recordsForDate.first.status == SugarStatus.good ? Colors.green : Colors.red)))),
            DataCell(Center(child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit), iconSize: 20, tooltip: 'Edit Record', onPressed: recordsForDate.length == 1 ? () => _showFormDialog(editing: recordsForDate.first) : null), IconButton(icon: const Icon(Icons.delete), iconSize: 20, tooltip: 'Delete all records for this date', onPressed: () => _showDeleteConfirmation(date, recordsForDate))]))), 
          ]);

          return DataRow(cells: cells);
        }).toList(),
      ),
    );
  }
  */

  //changes made here
  // Place this inside the _SugarDataScreenState class



// Helper to create a styled header cell.
  Widget _buildHeaderCell(String text, ThemeData theme, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // Replace the entire existing _recordsTable function with this one.


  //works but overflow
  Widget _recordsTable(ThemeData theme, Map<DateTime, List<SugarRecord>> groupedByDate, List<DateTime> sortedDates) {
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

    String formatHeader(String name) {
      if (name.isEmpty) return '';
      var result = name.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
      return result[0].toUpperCase() + result.substring(1);
    }

    // --- Define fixed widths for each column ---
    final List<double> columnWidths = [
      80.0, // Date
      80.0, // Time
      // 7 Meal Types * 2 columns each (Before/After)
      60.0, 60.0, // Breakfast
      60.0, 60.0, // Mid Morning Snack
      60.0, 60.0, // Lunch
      60.0, 60.0, // Afternoon Snack
      60.0, 60.0, // Dinner
      60.0, 60.0, // Evening Snack
      60.0, 60.0, // Before Bed
      60.0, // Status
      100.0, // Actions
    ];

    final double totalTableWidth = columnWidths.reduce((a, b) => a + b);

    // --- Helper for a styled header cell ---
    Widget headerCell(String text, double width, {bool isSubHeader = false}) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: (isSubHeader
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium)
              ?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      );
    }

    // --- Custom Header Builder ---
    Widget buildHeader() {
      int mealTypeStartIndex = 2; // Index after Date and Time
      return Container(
        color: theme.primaryColor,
        child: Column(
          children: [
            // --- Top Header Row ---
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerCell('Date', columnWidths[0]),
                  headerCell('Time', columnWidths[1]),
                  ...MealType.values.map((type) {
                    final width = columnWidths[mealTypeStartIndex] + columnWidths[mealTypeStartIndex + 1];
                    final widget = headerCell(formatHeader(type.name), width);
                    mealTypeStartIndex += 2;
                    return widget;
                  }).toList(),
                  headerCell('Status', columnWidths[16]),
                  headerCell('Actions', columnWidths[17]),
                ],
              ),
            ),
            // --- Bottom Header Row (Sub-header) ---
            Row(
              children: [
                Container(width: columnWidths[0] + columnWidths[1]), // Date & Time placeholder
                ...List.generate(7, (index) {
                  final baseIndex = 2 + (index * 2);
                  return Row(
                    children: [
                      headerCell('Before', columnWidths[baseIndex], isSubHeader: true),
                      headerCell('After', columnWidths[baseIndex + 1], isSubHeader: true),
                    ],
                  );
                }),
                Container(width: columnWidths[16] + columnWidths[17]), // Status & Actions placeholder
              ],
            ),
          ],
        ),
      );
    }

    // --- Custom Data Row Builder ---
    Widget buildDataRow(DateTime date, List<SugarRecord> records) {
      final timesString = records.map((r) => r.time.format(context)).join(',\n');
      final recordsMap = {for (var r in records) '${r.mealType.name}_${r.mealTimeCategory.name}': r};

      Widget dataCell(Widget child, double width) {
        return Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
          ),
          child: Center(child: child),
        );
      }

      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dataCell(Text(DateFormat('dd-MMM-yy').format(date)), columnWidths[0]),
              dataCell(Text(timesString), columnWidths[1]),
              ...MealType.values.expand((type) {
                int index = MealType.values.indexOf(type) * 2 + 2;
                final beforeRecord = recordsMap['${type.name}_${MealTimeCategory.before.name}'];
                final afterRecord = recordsMap['${type.name}_${MealTimeCategory.after.name}'];
                return [
                  dataCell(FittedBox(child: Text(beforeRecord?.value.toStringAsFixed(1) ?? '')) , columnWidths[index]),
                  dataCell(FittedBox(child: Text(afterRecord?.value.toStringAsFixed(1) ?? '')), columnWidths[index + 1]),
                ];
              }).toList(),
              dataCell(
                Tooltip(
                  message: records.first.status.name,
                  child: Icon(
                    records.first.status == SugarStatus.good ? Icons.check_circle_outline : Icons.highlight_off,
                    color: records.first.status == SugarStatus.good ? Colors.green : Colors.red,
                  ),
                ),
                columnWidths[16],
              ),
              dataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), iconSize: 20, tooltip: 'Edit Record', onPressed: records.length == 1 ? () => _showFormDialog(editing: records.first) : null),
                    IconButton(icon: const Icon(Icons.delete), iconSize: 20, tooltip: 'Delete all records for this date', onPressed: () => _showDeleteConfirmation(date, records)),
                  ],
                ),
                columnWidths[17],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalTableWidth,
        child: Column(
          children: [
            buildHeader(),
            ...paginatedDates.map((date) => buildDataRow(date, groupedByDate[date]!)).toList(),
          ],
        ),
      ),
    );
  }

  //original  and works also but not nice
  /*Widget _recordsTable(ThemeData theme, Map<DateTime, List<SugarRecord>> groupedByDate, List<DateTime> sortedDates) {
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

    String formatHeader(String name) {
      if (name.isEmpty) return '';
      var result = name.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
      return result[0].toUpperCase() + result.substring(1);
    }

    // --- Define fixed widths for each column ---
    final List<double> columnWidths = [
      85.0, // Date
      85.0, // Time
      // 7 Meal Types * 2 columns each (Before/After)
      70.0, 70.0, // Breakfast
      70.0, 70.0, // Mid Morning Snack
      70.0, 70.0, // Lunch
      70.0, 70.0, // Afternoon Snack
      70.0, 70.0, // Dinner
      70.0, 70.0, // Evening Snack
      70.0, 70.0, // Before Bed
      60.0, // Status
      80.0, // Actions
    ];
    final double totalTableWidth = columnWidths.reduce((a, b) => a + b);

    // --- Helper for a styled header cell ---
    Widget headerCell(String text, double width, {bool isSubHeader = false}) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: (isSubHeader
              ? theme.textTheme.bodySmall
              : theme.textTheme.bodyMedium)
              ?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      );
    }

    // --- Custom Header Builder ---
    Widget buildHeader() {
      int mealTypeStartIndex = 2; // Index after Date and Time
      return Container(
        color: theme.primaryColor,
        child: Column(
          children: [
            // --- Top Header Row ---
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerCell('Date', columnWidths[0]),
                  headerCell('Time', columnWidths[1]),
                  ...MealType.values.map((type) {
                    final width = columnWidths[mealTypeStartIndex] + columnWidths[mealTypeStartIndex + 1];
                    final widget = headerCell(formatHeader(type.name), width);
                    mealTypeStartIndex += 2;
                    return widget;
                  }).toList(),
                  headerCell('Status', columnWidths[16]),
                  headerCell('Actions', columnWidths[17]),
                ],
              ),
            ),
            // --- Bottom Header Row (Sub-header) ---
            Row(
              children: [
                Container(width: columnWidths[0] + columnWidths[1]), // Date & Time placeholder
                ...List.generate(7, (index) {
                  final baseIndex = 2 + (index * 2);
                  return Row(
                    children: [
                      headerCell('Before', columnWidths[baseIndex], isSubHeader: true),
                      headerCell('After', columnWidths[baseIndex + 1], isSubHeader: true),
                    ],
                  );
                }),
                Container(width: columnWidths[16] + columnWidths[17]), // Status & Actions placeholder
              ],
            ),
          ],
        ),
      );
    }

    // --- Custom Data Row Builder ---
    Widget buildDataRow(DateTime date, List<SugarRecord> records) {
      final timesString = records.map((r) => r.time.format(context)).join(',\n');
      final recordsMap = {for (var r in records) '${r.mealType.name}_${r.mealTimeCategory.name}': r};

      Widget dataCell(Widget child, double width) {
        return Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
          ),
          child: Center(child: child),
        );
      }

      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dataCell(Text(DateFormat('dd-MMM-yy').format(date)), columnWidths[0]),
              dataCell(Text(timesString), columnWidths[1]),
              ...MealType.values.expand((type) {
                int index = MealType.values.indexOf(type) * 2 + 2;
                final beforeRecord = recordsMap['${type.name}_${MealTimeCategory.before.name}'];
                final afterRecord = recordsMap['${type.name}_${MealTimeCategory.after.name}'];
                return [
                  dataCell(FittedBox(child: Text(beforeRecord?.value.toStringAsFixed(1) ?? '')) , columnWidths[index]),
                  dataCell(FittedBox(child: Text(afterRecord?.value.toStringAsFixed(1) ?? '')), columnWidths[index + 1]),
                ];
              }).toList(),
              dataCell(
                Tooltip(
                  message: records.first.status.name,
                  child: Icon(
                    records.first.status == SugarStatus.good ? Icons.check_circle_outline : Icons.highlight_off,
                    color: records.first.status == SugarStatus.good ? Colors.green : Colors.red,
                  ),
                ),
                columnWidths[16],
              ),
              dataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), iconSize: 20, tooltip: 'Edit Record', onPressed: records.length == 1 ? () => _showFormDialog(editing: records.first) : null),
                    IconButton(icon: const Icon(Icons.delete), iconSize: 20, tooltip: 'Delete all records for this date', onPressed: () => _showDeleteConfirmation(date, records)),
                  ],
                ),
                columnWidths[17],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: totalTableWidth,
        decoration: BoxDecoration(border: Border.all(color: theme.dividerColor, width: 1)),
        child: Column(
          children: [
            buildHeader(),
            ...paginatedDates.map((date) => buildDataRow(date, groupedByDate[date]!)).toList(),
          ],
        ),
      ),
    );
  }*/
  //changes end here

  void _showDeleteConfirmation(DateTime date, List<SugarRecord> records) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete all ${records.length} record(s) for ${DateFormat.yMd().format(date)}?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                for (var record in records) {
                  if (record.id != null) _deleteRecord(record.id!);
                }
              },
            ),
          ],
        );
      },
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
        DateFormat('dd-MMM-yyyy').format(DateTime.now());
    _timeController.text = editing?.time.format(context) ?? '';
    _sugarValueController.text = editing?.value.toString() ?? '';

    MealTimeCategory? cat = editing?.mealTimeCategory ?? MealTimeCategory.before;
    MealType? type = editing?.mealType ?? MealType.breakfast;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState2) => AlertDialog(
          title: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text(
              editing == null ? 'Add Record': 'Edit Record',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
                TextFormField(
                  controller: _sugarValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*$')), // digits + single dot
                  ],
                  decoration: InputDecoration(
                    labelText: 'Sugar Value',
                    hintText: _currentUnit == 'Metric' ? '0.5 – 25.0 mmol/L' : '9 – 450 mg/dL',
                  ),
                  validator: (value) {
                    final v = double.tryParse(value ?? '');
                    if (v == null) return 'Enter a valid number';
                    if (_currentUnit == 'Metric') {
                      if (v < 0.5 || v > 25.0) return 'Range 0.5 – 25.0 mmol/L';
                    } else {
                      if (v < 9 || v > 450) return 'Range 9 – 450 mg/dL';
                    };
                    return null;
                  },
                )
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