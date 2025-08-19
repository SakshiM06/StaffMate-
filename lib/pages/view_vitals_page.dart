import 'package:flutter/material.dart';
import '../models/vitals.dart';
import '../services/vitals_service.dart';
import 'vitals_detail_page.dart'; // ✅ make sure path is correct

class ViewVitalsPage extends StatelessWidget {
  const ViewVitalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<VitalsEntry> vitals = VitalsService.I.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Vitals')),
      body: vitals.isEmpty
          ? const Center(child: Text('No vitals saved yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vitals.length,
              itemBuilder: (context, index) {
                final v = vitals[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(v.patientName),
                    subtitle: Text(
                      '${v.date.day}-${v.date.month}-${v.date.year} @ ${v.hour}:${v.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VitalsDetailPage(vitals: v),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
