// // view_vitals_page.dart
// import 'package:flutter/material.dart';
// import 'package:staff_mate/models/vitals.dart';
// import 'package:staff_mate/services/vitals_service.dart';
// import 'package:staff_mate/pages/vitals_detail_page.dart'; // For viewing details

// class ViewVitalsPage extends StatelessWidget {
//   const ViewVitalsPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // For now, use mock data. You'll replace this with real data from your database
//     final List<VitalsEntry> vitals = [
//       VitalsEntry(
//         patientName: "John Doe",
//         date: DateTime.now(),
//         hour: 10,
//         minute: 30,
//         tempF: "98.6",
//         hr: "72",
//         rr: "18",
//         sysBp: "120",
//         diaBp: "80",
//         rbs: "100",
//         spo2: "98",
//       ),
//       VitalsEntry(
//         patientName: "Jane Smith",
//         date: DateTime.now().subtract(const Duration(days: 1)),
//         hour: 14,
//         minute: 45,
//         tempF: "99.2",
//         hr: "75",
//         rr: "20",
//         sysBp: "118",
//         diaBp: "78",
//         rbs: "110",
//         spo2: "97",
//       ),
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Saved Vitals'),
//         backgroundColor: const Color(0xFF1A237E),
//         foregroundColor: Colors.white,
//       ),
//       body: vitals.isEmpty
//           ? const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.assignment, size: 60, color: Colors.grey),
//                   SizedBox(height: 16),
//                   Text(
//                     'No vitals saved yet',
//                     style: TextStyle(
//                       fontSize: 16,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: vitals.length,
//               itemBuilder: (context, index) {
//                 final v = vitals[index];
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: ListTile(
//                     contentPadding: const EdgeInsets.all(16),
//                     leading: CircleAvatar(
//                       backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
//                       child: const Icon(
//                         Icons.favorite,
//                         color: Color(0xFF1A237E),
//                         size: 20,
//                       ),
//                     ),
//                     title: Text(
//                       v.patientName,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 16,
//                       ),
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const SizedBox(height: 4),
//                         Text(
//                           '${v.date.day}-${v.date.month}-${v.date.year} @ ${v.hour}:${v.minute.toString().padLeft(2, '0')}',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Row(
//                           children: [
//                             _buildVitalChip('Temp: ${v.tempF}°F'),
//                             const SizedBox(width: 8),
//                             _buildVitalChip('HR: ${v.hr}'),
//                             const SizedBox(width: 8),
//                             _buildVitalChip('BP: ${v.sysBp}/${v.diaBp}'),
//                           ],
//                         ),
//                       ],
//                     ),
//                     trailing: const Icon(
//                       Icons.arrow_forward_ios,
//                       size: 16,
//                       color: Colors.grey,
//                     ),
//                     onTap: () {
//                       // Navigate to view vitals details page
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           // FIX: Only pass the vitals parameter, not patient
//                           // VitalsDetailPage only needs VitalsEntry, not a Patient object
//                           builder: (_) => VitalsDetailPage(vitals: v, patient: null),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//     );
//   }

//   Widget _buildVitalChip(String text) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Text(
//         text,
//         style: const TextStyle(
//           fontSize: 11,
//           color: Colors.grey,
//         ),
//       ),
//     );
//   }
// }