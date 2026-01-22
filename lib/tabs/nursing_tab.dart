import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NursingListTab extends StatelessWidget {
  final ScrollController scrollController;
  
  const NursingListTab({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
     // TODO: Fetch from API
     final List<String> tasks = ["Catheter Care", "Steam Inhalation", "Back Care", "Sponge Bath"];
     
     return ListView.builder(
       controller: scrollController,
       padding: const EdgeInsets.all(16),
       itemCount: tasks.length,
       itemBuilder: (context, index) {
         return Card(
           elevation: 0,
           margin: const EdgeInsets.only(bottom: 8),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
           child: CheckboxListTile(
             activeColor: const Color(0xFF1A237E),
             title: Text(tasks[index], style: GoogleFonts.poppins(fontSize: 14)),
             subtitle: const Text("Twice daily", style: TextStyle(fontSize: 11)),
             value: index % 2 == 0, // Mock value
             onChanged: (val) {
               // Update logic here
             },
           ),
         );
       },
     );
  }
}