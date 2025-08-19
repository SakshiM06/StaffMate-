import 'package:flutter/material.dart';
import 'package:staff_mate/models/patient.dart';

class CreatePatientPage extends StatefulWidget {
  final void Function(Patient) onSave;

  const CreatePatientPage({super.key, required this.onSave});

  @override
  State<CreatePatientPage> createState() => _CreatePatientPageState();
}

class _CreatePatientPageState extends State<CreatePatientPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController diagnosisController = TextEditingController();
  String gender = "Male"; // default
  bool isNew = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Patient")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (v) => setState(() => gender = v ?? "Male"),
                decoration: const InputDecoration(labelText: "Gender"),
              ),
              TextField(
                controller: diagnosisController,
                decoration: const InputDecoration(labelText: "Diagnosis"),
              ),
              SwitchListTile(
                title: const Text("Is New Case?"),
                value: isNew,
                onChanged: (val) => setState(() => isNew = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final patient = Patient(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(), // temporary id
                    name: nameController.text,
                    age: int.tryParse(ageController.text) ?? 0,
                    gender: gender,
                    diagnosis: diagnosisController.text,
                    isNew: isNew,
                  );

                  widget.onSave(patient);
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
