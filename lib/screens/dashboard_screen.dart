import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/models/sugar_record.dart';
import 'package:jagadiri/models/bp_record.dart';
import 'dart:math'; // Import for min and max
import 'package:jagadiri/services/database_service.dart'; // Import DatabaseService

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SugarRecord> _sugarRecords = [];
  List<BPRecord> _bpRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      _sugarRecords = await databaseService.getSugarRecords();
      _bpRecords = await databaseService.getBPRecords();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data from database: \${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to calculate average for a list of doubles
  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // Helper to calculate average for a list of ints
  double _calculateIntAverage(List<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate metrics for Sugar
    final allSugarValues = _sugarRecords.map((record) => record.value).toList();
    final sugarMax = allSugarValues.isNotEmpty ? allSugarValues.reduce(max) : 0.0;
    final sugarMin = allSugarValues.isNotEmpty ? allSugarValues.reduce(min) : 0.0;
    final sugarAvg = _calculateAverage(allSugarValues);
    // Simple dummy logic for trend based on average
    final sugarTrend = sugarAvg > 100 ? 'Deteriorating' : 'Improving'; 

    // Calculate metrics for BP
    final allSystolicValues = _bpRecords.map((record) => record.systolic).toList();
    final allDiastolicValues = _bpRecords.map((record) => record.diastolic).toList();
    final bpSystolicMax = allSystolicValues.isNotEmpty ? allSystolicValues.reduce(max) : 0;
    final bpSystolicMin = allSystolicValues.isNotEmpty ? allSystolicValues.reduce(min) : 0;
    final bpSystolicAvg = _calculateIntAverage(allSystolicValues);
    final bpDiastolicMax = allDiastolicValues.isNotEmpty ? allDiastolicValues.reduce(max) : 0;
    final bpDiastolicMin = allDiastolicValues.isNotEmpty ? allDiastolicValues.reduce(min) : 0;
    final bpDiastolicAvg = _calculateIntAverage(allDiastolicValues);
    final bpTrend = (bpSystolicAvg > 130 || bpDiastolicAvg > 85) ? 'Deteriorating' : 'Improving'; // Simple dummy logic

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to your Health Overview!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _buildHealthMetricCard(
              context,
              title: 'Blood Sugar Overview',
              max: sugarMax.toStringAsFixed(1),
              min: sugarMin.toStringAsFixed(1),
              avg: sugarAvg.toStringAsFixed(1),
              trend: sugarTrend,
              trendColor: sugarTrend == 'Improving' ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),
            _buildHealthMetricCard(
              context,
              title: 'Blood Pressure Overview',
              max: '\$bpSystolicMax/\$bpDiastolicMax',
              min: '\$bpSystolicMin/\$bpDiastolicMin',
              avg: '\${bpSystolicAvg.toStringAsFixed(0)}/\${bpDiastolicAvg.toStringAsFixed(0)}',
              trend: bpTrend,
              trendColor: bpTrend == 'Improving' ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetricCard(
    BuildContext context,
    {required String title,
    required String max,
    required String min,
    required String avg,
    required String trend,
    required Color trendColor,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildMetricRow(context, 'Max', max),
            _buildMetricRow(context, 'Min', min),
            _buildMetricRow(context, 'Avg', avg),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Trend: ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  trend,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value) {
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
            value,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
