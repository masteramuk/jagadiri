import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'package:jagadiri/services/database_service.dart';
import 'package:collection/collection.dart';
import 'package:jagadiri/models/user_profile.dart';
import 'package:jagadiri/providers/user_profile_provider.dart';

class BPDataScreen extends StatefulWidget {
  const BPDataScreen({super.key});

  @override
  State<BPDataScreen> createState() => _BPDataScreenState();
}

enum DisplayMode { all, top20HighSystolic, top20HighDiastolic }

class _BPDataScreenState extends State<BPDataScreen> {
  /* -------------------- State -------------------- */
  List<BPRecord> _bpRecords = [];
  List<BPRecord> _filteredBPRecords = [];
  List<BPRecord> _currentlyDisplayedRecords = [];
  DisplayMode _displayMode = DisplayMode.all;
  bool _isLoading = true;
  bool _isLatestCardExpanded = false;
  bool _isSearchCardExpanded = false;

  /* -------------------- Search -------------------- */
  final _searchStartDateController = TextEditingController();
  final _searchEndDateController = TextEditingController();

  /* -------------------- Pagination -------------------- */
  int _currentPage = 0;
  int _rowsPerPage = 5;
  final List<int> _rowsPerPageOptions = [5, 10, 20, 50, 100];

  /* -------------------- Form -------------------- */
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseRateController = TextEditingController();

  /* -------------------- Life-cycle -------------------- */
  @override
  void initState() {
    super.initState();
    _fetchBPRecords();
  }

  @override
  void dispose() {
    _searchStartDateController.dispose();
    _searchEndDateController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseRateController.dispose();
    super.dispose();
  }

  /* -------------------- Data fetching -------------------- */
  Future<void> _fetchBPRecords() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      _bpRecords = await db.getBPRecords();
      _bpRecords.sort((a, b) => b.date.compareTo(a.date));
      _filter();
    } catch (e) {
      debugPrint('Error fetching BP records: $e');
    }
    setState(() => _isLoading = false);
  }

  /* -------------------- Filtering -------------------- */
  void _filter() {
    setState(() {
      _displayMode = DisplayMode.all;
      _currentPage = 0;
      _filteredBPRecords = _bpRecords.where((rec) {
        final d = rec.date;
        final s = _searchStartDateController.text.isEmpty
            ? null
            : DateFormat('dd-MMM-yyyy').parse(_searchStartDateController.text);
        final e = _searchEndDateController.text.isEmpty
            ? null
            : DateFormat('dd-MMM-yyyy').parse(_searchEndDateController.text);

        if (s != null && d.isBefore(s)) return false;
        if (e != null && d.isAfter(e)) return false;
        return true;
      }).toList();
    });
    _updateDisplayedRecords();
  }

  /* -------------------- Display Logic -------------------- */
  void _updateDisplayedRecords() {
    setState(() {
      _currentPage = 0;
      switch (_displayMode) {
        case DisplayMode.all:
          _currentlyDisplayedRecords = _filteredBPRecords;
          break;
        case DisplayMode.top20HighSystolic:
          final sorted = List<BPRecord>.from(_bpRecords)
            ..sort((a, b) {
              final valueComparison = b.systolic.compareTo(a.systolic);
              if (valueComparison != 0) return valueComparison;
              return b.date.compareTo(a.date);
            });
          _currentlyDisplayedRecords = sorted.take(20).toList();
          break;
        case DisplayMode.top20HighDiastolic:
          final sorted = List<BPRecord>.from(_bpRecords)
            ..sort((a, b) {
              final valueComparison = b.diastolic.compareTo(a.diastolic);
              if (valueComparison != 0) return valueComparison;
              return b.date.compareTo(a.date);
            });
          _currentlyDisplayedRecords = sorted.take(20).toList();
          break;
      }
    });
  }

  /* -------------------- Date / Time Pickers -------------------- */
  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365 * 100)),
      lastDate: now.add(const Duration(days: 365 * 100)),
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
  Future<void> _saveRecord(BPTimeName? timeName, [BPRecord? editing]) async {
    if (_dateController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _systolicController.text.isEmpty ||
        _diastolicController.text.isEmpty ||
        _pulseRateController.text.isEmpty ||
        timeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final date = DateFormat('dd-MMM-yyyy').parse(_dateController.text);
    final time = TimeOfDay.fromDateTime(
        DateFormat('hh:mm a').parse(_timeController.text));
    final systolic = int.tryParse(_systolicController.text) ?? 0;
    final diastolic = int.tryParse(_diastolicController.text) ?? 0;
    final pulseRate = int.tryParse(_pulseRateController.text) ?? 0;

    final userProfile = Provider.of<UserProfileProvider>(context, listen: false).userProfile;
    final age = userProfile != null ? DateTime.now().year - userProfile.dob.year : 0;

    final status = _calculateBPStatus(systolic, diastolic, age);

    final record = BPRecord(
      id: editing?.id,
      date: date,
      time: time,
      timeName: timeName,
      systolic: systolic,
      diastolic: diastolic,
      pulseRate: pulseRate,
      status: status,
    );

    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      editing == null
          ? await db.insertBPRecord(record)
          : await db.updateBPRecord(record);
      Navigator.pop(context);
      _fetchBPRecords();
      _clearForm();
      _showSuccessSnackBar('Record saved successfully.');
    } catch (e) {
      _showErrorSnackBar('Failed to save record. Please try again.');
    }
  }

  Future<void> _deleteRecord(int id) async {
    await Provider.of<DatabaseService>(context, listen: false)
        .deleteBPRecord(id);
  }

  void _clearForm() {
    _dateController.clear();
    _timeController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _pulseRateController.clear();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /* -------------------- UI -------------------- */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groupedByDate = groupBy(
      _currentlyDisplayedRecords,
      (BPRecord r) => DateTime(r.date.year, r.date.month, r.date.day),
    );
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('BP & Pulse Monitor')),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onPressed: onToggle,
            ),
            onTap: onToggle,
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

  String _formatTimeName(String timeName) {
    if (timeName.isEmpty) return '';
    var result = timeName.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ');
    return result[0].toUpperCase() + result.substring(1);
  }

  BPStatus _calculateBPStatus(int systolic, int diastolic, int age) {
    if (age >= 18 && age <= 65) {
      if (systolic < 90 || diastolic < 60) return BPStatus.bad;
      if (systolic >= 90 && systolic <= 120 && diastolic >= 60 && diastolic <= 80) return BPStatus.excellent;
      if (systolic > 120 && systolic <= 130 && diastolic >= 60 && diastolic <= 80) return BPStatus.normal;
      if (systolic > 130 && systolic <= 140 && diastolic >= 80 && diastolic <= 90) return BPStatus.borderline;
      if (systolic > 140 || diastolic > 90) return BPStatus.bad;
    } else if (age > 65) {
      if (systolic < 90 || diastolic < 60) return BPStatus.bad;
      if (systolic >= 90 && systolic <= 130 && diastolic >= 60 && diastolic <= 90) return BPStatus.excellent;
      if (systolic > 130 && systolic <= 140 && diastolic >= 80 && diastolic <= 90) return BPStatus.normal;
      if (systolic > 140 && systolic <= 150 && diastolic >= 90 && diastolic <= 95) return BPStatus.borderline;
      if (systolic > 150 || diastolic > 95) return BPStatus.bad;
    }
    return BPStatus.worst;
  }

  /* -------------------- Summary Cards -------------------- */
  Widget _summaryCards() {
    if (_filteredBPRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard('Min', 'NA', 'NA'),
              _buildSummaryCard('Max', 'NA', 'NA'),
              _buildSummaryCard('Avg', 'NA', 'NA'),
              _buildSummaryCard('Trend', null, null, isTrend: true),
            ],
          ),
        ),
      );
    }

    final minSystolic = _filteredBPRecords.map((e) => e.systolic).reduce((a, b) => a < b ? a : b);
    final maxSystolic = _filteredBPRecords.map((e) => e.systolic).reduce((a, b) => a > b ? a : b);
    final avgSystolic = _filteredBPRecords.map((e) => e.systolic).reduce((a, b) => a + b) / _filteredBPRecords.length;

    final minDiastolic = _filteredBPRecords.map((e) => e.diastolic).reduce((a, b) => a < b ? a : b);
    final maxDiastolic = _filteredBPRecords.map((e) => e.diastolic).reduce((a, b) => a > b ? a : b);
    final avgDiastolic = _filteredBPRecords.map((e) => e.diastolic).reduce((a, b) => a + b) / _filteredBPRecords.length;

    final minPulse = _filteredBPRecords.map((e) => e.pulseRate).reduce((a, b) => a < b ? a : b);
    final maxPulse = _filteredBPRecords.map((e) => e.pulseRate).reduce((a, b) => a > b ? a : b);
    final avgPulse = _filteredBPRecords.map((e) => e.pulseRate).reduce((a, b) => a + b) / _filteredBPRecords.length;

    IconData trendIcon = Icons.trending_flat;
    Color? trendColor;
    if (_filteredBPRecords.length > 1) {
      final latest = _filteredBPRecords.first;
      final previous = _filteredBPRecords[1];
      if (latest.systolic > previous.systolic || latest.diastolic > previous.diastolic) {
        trendIcon = Icons.trending_up;
        trendColor = Colors.red;
      } else if (latest.systolic < previous.systolic || latest.diastolic < previous.diastolic) {
        trendIcon = Icons.trending_down;
        trendColor = Colors.green;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard('Min', '$minSystolic/$minDiastolic', '$minPulse bpm'),
            _buildSummaryCard('Max', '$maxSystolic/$maxDiastolic', '$maxPulse bpm'),
            _buildSummaryCard('Avg', '${avgSystolic.toStringAsFixed(0)}/${avgDiastolic.toStringAsFixed(0)}', '${avgPulse.toStringAsFixed(0)} bpm'),
            _buildSummaryCard('Trend', null, null, isTrend: true, trendIcon: trendIcon, trendColor: trendColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String? value1, String? value2, {bool isTrend = false, IconData? trendIcon, Color? trendColor}) {
    return Expanded(
      child: Card(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (isTrend)
                Icon(trendIcon ?? Icons.trending_flat, color: trendColor ?? Colors.grey)
              else ...[
                Text(value1 ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(value2 ?? ''),
              ]
            ],
          ),
        ),
      ),
    );
  }

  /* -------------------- Latest Record -------------------- */
  Widget _latestCard() {
    if (_bpRecords.isEmpty) return const SizedBox.shrink();
    final latest = _bpRecords.first;
    final dt = DateTime(
      latest.date.year,
      latest.date.month,
      latest.date.day,
      latest.time.hour,
      latest.time.minute,
    );

    IconData trendIcon = Icons.trending_flat;
    Color? trendColor;
    if (_bpRecords.length > 1) {
      final previous = _bpRecords[1];
      if (latest.systolic > previous.systolic || latest.diastolic > previous.diastolic) {
        trendIcon = Icons.trending_up;
        trendColor = Colors.red;
      } else if (latest.systolic < previous.systolic || latest.diastolic < previous.diastolic) {
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
              Text(
                DateFormat('dd-MMM-yyyy  hh:mm a').format(dt),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimeName(latest.timeName.name),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${latest.systolic}/${latest.diastolic} mmHg',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${latest.pulseRate} bpm',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(latest.status),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _filter,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _searchStartDateController.clear();
                  _searchEndDateController.clear();
                  _filter();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _displayMode = DisplayMode.top20HighSystolic);
                  _updateDisplayedRecords();
                  _showSuccessSnackBar('Displaying Top 20 High Systolic Records.');
                },
                child: const Text('Top 20 High Systolic'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _displayMode = DisplayMode.top20HighDiastolic);
                  _updateDisplayedRecords();
                  _showSuccessSnackBar('Displaying Top 20 High Diastolic Records.');
                },
                child: const Text('Top 20 High Diastolic'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recordsTable(ThemeData theme, Map<DateTime, List<BPRecord>> groupedByDate, List<DateTime> sortedDates) {
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Systolic')),
          DataColumn(label: Text('Diastolic')),
          DataColumn(label: Text('Pulse')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Trend')),
          DataColumn(label: Text('Actions')),
        ],
        rows: paginatedDates.expand((date) {
          final records = groupedByDate[date]!;
          return List.generate(records.length, (i) {
            final record = records[i];
            final prev = i > 0 ? records[i - 1] : null;
            return DataRow(cells: [
              DataCell(Text(DateFormat('dd-MMM-yy').format(record.date))),
              DataCell(Text(record.time.format(context))),
              DataCell(Text(record.systolic.toString())),
              DataCell(Text(record.diastolic.toString())),
              DataCell(Text(record.pulseRate.toString())),
              DataCell(_buildStatusIcon(record.status)),
              DataCell(_buildTrendIcon(record, prev)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showFormDialog(editing: record),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteConfirmation(record.id!),
                  ),
                ],
              )),
            ]);
          });
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIcon(BPStatus status) {
    switch (status) {
      case BPStatus.excellent:
        return const Icon(Icons.favorite, color: Colors.green, size: 24);
      case BPStatus.normal:
        return const Icon(Icons.monitor_heart, color: Colors.blue, size: 24);
      case BPStatus.borderline:
        return const Icon(Icons.warning, color: Colors.orange, size: 24);
      case BPStatus.bad:
        return const Icon(Icons.thumb_down, color: Colors.red, size: 24);
      case BPStatus.worst:
        return const Icon(Icons.bolt, color: Colors.purple, size: 24);
      default:
        return const Icon(Icons.help, color: Colors.grey, size: 24);
    }
  }

  Widget _buildTrendIcon(BPRecord current, BPRecord? previous) {
    if (previous == null) {
      return const Icon(Icons.trending_flat, color: Colors.grey, size: 20);
    }
    final isImproving = (current.systolic < previous.systolic && current.diastolic < previous.diastolic);
    final isDeteriorating = (current.systolic > previous.systolic && current.diastolic > previous.diastolic);
    if (isImproving) {
      return const Icon(Icons.trending_down, color: Colors.green, size: 20);
    } else if (isDeteriorating) {
      return const Icon(Icons.trending_up, color: Colors.red, size: 20);
    } else {
      return const Icon(Icons.trending_flat, color: Colors.grey, size: 20);
    }
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteRecord(id);
              Navigator.pop(context);
              _fetchBPRecords();
              _showSuccessSnackBar('Record deleted successfully.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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
  void _showFormDialog({BPRecord? editing}) {
    if (editing == null) {
      _clearForm();
      _dateController.text = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    } else {
      _dateController.text = DateFormat('dd-MMM-yyyy').format(editing.date);
      _timeController.text = editing.time.format(context);
      _systolicController.text = editing.systolic.toString();
      _diastolicController.text = editing.diastolic.toString();
      _pulseRateController.text = editing.pulseRate.toString();
    }

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
              editing == null ? 'Add BP Record' : 'Edit BP Record',
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
                  onTap: editing == null ? () => _pickDate(_dateController) : null,
                ),
                TextField(
                  controller: _timeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Time', suffixIcon: Icon(Icons.access_time)),
                  onTap: editing == null ? _pickTime : null,
                ),
                TextFormField(
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Systolic (mmHg)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter systolic';
                    final v = int.tryParse(value);
                    if (v == null || v < 50 || v > 250) return 'Enter valid systolic (50-250)';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Diastolic (mmHg)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter diastolic';
                    final v = int.tryParse(value);
                    if (v == null || v < 30 || v > 150) return 'Enter valid diastolic (30-150)';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _pulseRateController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Pulse Rate (bpm)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter pulse rate';
                    final v = int.tryParse(value);
                    if (v == null || v < 30 || v > 220) return 'Enter valid pulse (30-220)';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                // Automatically set timeName based on selected time
                final time = TimeOfDay.fromDateTime(
                    DateFormat('hh:mm a').parse(_timeController.text));
                BPTimeName timeName = _getTimeNameFromTime(time);
                _saveRecord(timeName, editing);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  BPTimeName _getTimeNameFromTime(TimeOfDay time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return BPTimeName.morning;
    if (hour >= 12 && hour < 17) return BPTimeName.afternoon;
    if (hour >= 17 && hour < 21) return BPTimeName.evening;
    return BPTimeName.night;
  }
}
