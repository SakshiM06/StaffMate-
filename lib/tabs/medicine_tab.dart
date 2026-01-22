import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// TODO: Import your API service here if needed to fetch real meds
// import 'package:staff_mate/api/ipd_service.dart';

class MedicineListTab extends StatefulWidget {
  final ScrollController scrollController;
  final String patientId; // Useful for API calls

  const MedicineListTab({
    super.key, 
    required this.scrollController, 
    required this.patientId
  });

  @override
  State<MedicineListTab> createState() => _MedicineListTabState();
}

class _MedicineListTabState extends State<MedicineListTab> {
  // TODO: Replace this with data fetched from your Backend/Service
  final List<Map<String, dynamic>> meds = [
    {"name": "Saaz-DS Tablet", "route": "INTRAMUSCULAR", "dose": "1-1-0", "status": "pending", "remark": ""},
    {"name": "Inj. Pantocid", "route": "IV", "dose": "1-0-1", "status": "pending", "remark": ""},
    {"name": "Paracetamol 500mg", "route": "ORAL", "dose": "1-0-1", "status": "given", "time": "10:30 AM", "remark": "Mild fever"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: meds.length,
      itemBuilder: (context, index) {
        final med = meds[index];
        bool isGiven = med['status'] == "given";
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isGiven ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isGiven ? Colors.green.withOpacity(0.3) : Colors.grey.shade300),
            boxShadow: isGiven ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side: Medicine Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(med['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: isGiven ? Colors.grey : Colors.black87)),
                              const SizedBox(width: 8),
                              _buildTag(med['route'], Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildInfoBadge(Icons.timer_outlined, med['dose']),
                              const SizedBox(width: 12),
                              if(isGiven) _buildInfoBadge(Icons.check_circle_outline, "Given ${med['time']}", color: Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right Side: Checkbox Action
                    Transform.scale(
                      scale: 1.3,
                      child: Checkbox(
                        value: isGiven,
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          // TODO: Call your Service API here to update status
                          setState(() {
                             med['status'] = val == true ? "given" : "pending";
                             if(val == true) med['time'] = DateFormat('hh:mm a').format(DateTime.now());
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom: Remark Input (Visible if active or has remark)
              if (!isGiven || (med['remark'] != null && med['remark'].isNotEmpty))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isGiven 
                        ? Text(med['remark'].isEmpty ? "No remarks" : med['remark'], style: const TextStyle(fontSize: 12, color: Colors.grey))
                        : TextField(
                            decoration: const InputDecoration.collapsed(hintText: "Add Remark (Optional)", hintStyle: TextStyle(fontSize: 12, color: Colors.grey)),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (val) => med['remark'] = val,
                          ),
                      ),
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, color: color.shade800, fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildInfoBadge(IconData icon, String text, {Color color = Colors.grey}) {
    return Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500))]);
  }
}