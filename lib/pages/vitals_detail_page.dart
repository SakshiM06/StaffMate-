import 'package:flutter/material.dart';
import '../models/vitals.dart'; // Update path as needed

class VitalsDetailPage extends StatelessWidget {
  final VitalsEntry vitals;

  const VitalsDetailPage({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vitals Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow("Patient Name", vitals.patientName),
            _buildRow("Date", '${vitals.date.day}-${vitals.date.month}-${vitals.date.year}'),
            _buildRow("Time", '${vitals.hour}:${vitals.minute.toString().padLeft(2, '0')}'),
            const Divider(),
            _buildRow("Temperature (°F)", vitals.tempF),
            _buildRow("Heart Rate", vitals.hr),
            _buildRow("Respiratory Rate", vitals.rr),
            _buildRow("Systolic BP", vitals.sysBp),
            _buildRow("Diastolic BP", vitals.diaBp),
            _buildRow("RBS", vitals.rbs),
            _buildRow("SpO₂", vitals.spo2),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
