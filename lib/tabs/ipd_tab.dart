import 'package:flutter/material.dart';

class IPDTab extends StatelessWidget {
  const IPDTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.local_hospital, color: Colors.black),
            title: Text('In-Patient Department'),
            subtitle: Text('Manage admissions, beds, and IPD workflow.'),
          ),
        ),
      ],
    );
  }
}
