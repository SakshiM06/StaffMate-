import 'package:flutter/material.dart';
import '../models/bed.dart';

class BedCard extends StatelessWidget {
  final Bed bed;

  const BedCard({super.key, required this.bed});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bed.isAvailable ? Colors.green : Colors.red,
          child: Text(bed.bedNo),
        ),
        title: Text("${bed.wardType} - ${bed.category}"),
        subtitle: Text(bed.isAvailable
            ? "Available"
            : "${bed.patientName} (${bed.ageGender}) - ${bed.ipdNo}\nDoctor: ${bed.doctorName}"),
        isThreeLine: true,
      ),
    );
  }
}
