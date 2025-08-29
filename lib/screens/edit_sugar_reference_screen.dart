import 'package:flutter/material.dart';
import 'package:jagadiri/models/sugar_ref_model.dart';
import 'package:jagadiri/services/database_service.dart';

class EditSugarReferenceScreen extends StatefulWidget {
  const EditSugarReferenceScreen({super.key});

  @override
  State<EditSugarReferenceScreen> createState() => _EditSugarReferenceScreenState();
}

class _EditSugarReferenceScreenState extends State<EditSugarReferenceScreen> {
  late Future<List<SugarRefModel>> _sugarReferencesFuture;
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _minControllers;
  late List<TextEditingController> _maxControllers;
  String _currentUnit = 'mmol/L';

  @override
  void initState() {
    super.initState();
    _loadSugarReferences();
  }

  void _loadSugarReferences() {
    _sugarReferencesFuture = DatabaseService().getSugarReferences(_currentUnit);
    _sugarReferencesFuture.then((refs) {
      _minControllers = refs.map((ref) => TextEditingController(text: ref.min.toString())).toList();
      _maxControllers = refs.map((ref) => TextEditingController(text: ref.max.toString())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Sugar Reference'),
        actions: [
          DropdownButton<String>(
            value: _currentUnit,
            items: <String>['mmol/L', 'mg/dL']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _currentUnit = newValue!;
                _loadSugarReferences();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: FutureBuilder<List<SugarRefModel>>(
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
                  DataColumn(label: Text('Min Value')),
                  DataColumn(label: Text('Max Value')),
                ],
                rows: List<DataRow>.generate(sugarRefs.length, (index) {
                  final ref = sugarRefs[index];
                  return DataRow(
                    cells: [
                      DataCell(Text(ref.scenario)),
                      DataCell(Text(ref.mealTime)),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _minControllers[index],
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
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _maxControllers[index],
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
                        ),
                      ),
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

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      _sugarReferencesFuture.then((refs) {
        for (int i = 0; i < refs.length; i++) {
          final ref = refs[i];
          final newMin = double.parse(_minControllers[i].text);
          final newMax = double.parse(_maxControllers[i].text);
          final updatedRef = SugarRefModel(
            id: ref.id,
            scenario: ref.scenario,
            unit: ref.unit,
            mealTime: ref.mealTime,
            min: newMin,
            max: newMax,
          );
          DatabaseService().updateSugarRef(updatedRef);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      });
    }
  }
}
