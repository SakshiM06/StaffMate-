import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart'; 

class PatientGridCard extends StatelessWidget {
  final Patient patient;

  const PatientGridCard({super.key, required this.patient});

  Color _getCardColor() {
   
    if (patient.dischargeStatus != '0') { 
      return Colors.yellow.shade600;
    }

    String wardLower = patient.ward.toLowerCase();
    switch (wardLower) {
      case 'gen':
      case 'twin sharing':
      return Colors.blue.shade400;
      case 'dlx':
        return Colors.lime.shade400;
      case 'icu':
        return Colors.green.shade400;
      case 'suite':
        return Colors.red.shade400;
      case 'icu | 301':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      clipBehavior: Clip.antiAlias,
      color: _getCardColor(), 
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            Text(
              '${patient.ward.toUpperCase()} | ${patient.bedname}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text('IPD NO : (${patient.ipdNo})', style: TextStyle(fontSize: 12, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              patient.patientname,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text('${patient.age}Y / ${patient.gender.toUpperCase()} (${patient.party})', style: TextStyle(fontSize: 12, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd-MM-yyyy HH:mm').format(patient.admissionDateTime),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text('DR. ${patient.practitionername.toUpperCase()}', style: TextStyle(fontSize: 12, color: Colors.white)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Icon(Icons.comment_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Icon(Icons.favorite_border_outlined, color: Colors.white, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}