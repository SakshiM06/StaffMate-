import 'package:flutter/material.dart';

class OPDTabContent extends StatelessWidget {
  const OPDTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.medical_services, color: Colors.teal),
            title: Text('Out-Patient Department'),
            subtitle: Text('Consultations, check-ups, and visits.'),
          ),
        ),
      ],
    );
  }
}
