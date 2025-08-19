import 'package:flutter/material.dart';
import 'package:staff_mate/models/patient.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  const PatientCard({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: patient.isNew ? Colors.green : Colors.orange,
          child: Text(patient.name[0].toUpperCase()),
        ),
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${patient.age} yrs • ${patient.gender}\n${patient.diagnosis}"),
        isThreeLine: true,
        trailing: patient.isNew
            ? const Icon(Icons.fiber_new, color: Colors.green)
            : const Icon(Icons.history, color: Colors.orange),
      ),
    );
  }
}
