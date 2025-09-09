import 'package:flutter/material.dart';
import 'package:jagadiri/models/sugar_reference.dart';
import 'package:jagadiri/services/database_service.dart';

class EditSugarReferenceScreen extends StatefulWidget {
  const EditSugarReferenceScreen({super.key});

  @override
  State<EditSugarReferenceScreen> createState() => _EditSugarReferenceScreenState();
}

class _EditSugarReferenceScreenState extends State<EditSugarReferenceScreen> {
  late Future<List<SugarReference>> _sugarReferencesFuture;
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _minMmolLControllers;
  late List<TextEditingController> _maxMmolLControllers;
  late List<TextEditingController> _minMgdLControllers;
  late List<TextEditingController> _maxMgdLControllers;

  @override
  void initState() {
    super.initState();
    _loadSugarReferences();
  }

  void _loadSugarReferences() {
    _sugarReferencesFuture = DatabaseService().getSugarReferences();
    _sugarReferencesFuture.then((refs) {
      _minMmolLControllers = refs.map((ref) => TextEditingController(text: ref.minMmolL.toString())).toList();
      _maxMmolLControllers = refs.map((ref) => TextEditingController(text: ref.maxMmolL.toString())).toList();
      _minMgdLControllers = refs.map((ref) => TextEditingController(text: ref.minMgdL.toString())).toList();
      _maxMgdLControllers = refs.map((ref) => TextEditingController(text: ref.maxMgdL.toString())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Sugar Reference'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: FutureBuilder<List<SugarReference>>(
        future: _sugarReferencesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No sugar references found.'));
          }

          final sugarRefs = snapshot.data!;
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Scenario')),
                  DataColumn(label: Text('Meal Time')),
                  DataColumn(label: Text('Min (mmol/L)')),
                  DataColumn(label: Text('Max (mmol/L)')),
                  DataColumn(label: Text('Min (mg/dL)')),
                  DataColumn(label: Text('Max (mg/dL)')),
                ],
                rows: List<DataRow>.generate(sugarRefs.length, (index) {
                  final ref = sugarRefs[index];
                  return DataRow(
                    cells: [
                      DataCell(Text(ref.scenario)),
                      DataCell(Text(ref.mealTime.name)),
                      DataCell(_buildTextFormField(_minMmolLControllers[index])),
                      DataCell(_buildTextFormField(_maxMmolLControllers[index])),
                      DataCell(_buildTextFormField(_minMgdLControllers[index])),
                      DataCell(_buildTextFormField(_maxMgdLControllers[index])),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller) {
    return SizedBox(
      width: 100,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      _sugarReferencesFuture.then((refs) {
        for (int i = 0; i < refs.length; i++) {
          final ref = refs[i];
          final updatedRef = SugarReference(
            id: ref.id,
            scenario: ref.scenario,
            mealTime: ref.mealTime,
            minMmolL: double.parse(_minMmolLControllers[i].text),
            maxMmolL: double.parse(_maxMmolLControllers[i].text),
            minMgdL: double.parse(_minMgdLControllers[i].text),
            maxMgdL: double.parse(_maxMgdLControllers[i].text),
          );
          DatabaseService().updateSugarRef(updatedRef);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Changes saved successfully')),
          );
        }
      });
    }
  }
}