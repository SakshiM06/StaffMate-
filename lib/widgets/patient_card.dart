import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/models/patient.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  const PatientCard({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
  final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        
child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    patient.patientname,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // if (patient.isNew)
                //   Container(
                //     padding:
                //         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //     decoration: BoxDecoration(
                //       color: Colors.orange.shade200,
                //       borderRadius: BorderRadius.circular(6),
                //     ),
                //     child: const Text('NEW',
                //         style: TextStyle(
                //             color: Colors.black87,
                //             fontWeight: FontWeight.bold,
                //             fontSize: 10)),
                //   ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(
                Icons.personal_injury_outlined, 'IPD No', patient.ipdNo),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.king_bed_outlined, 'Ward | Bed',
                '${patient.ward} | ${patient.bedname}'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person_outline, 'Age', '${patient.age} yrs'),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Admission',
              '${formatter.format(patient.admissionDateTime)} (${patient.scdNo})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}