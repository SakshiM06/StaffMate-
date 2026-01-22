import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/models/patient.dart';
// Import the tabs we will create next
import 'package:staff_mate/tabs/medicine_tab.dart';
import 'package:staff_mate/tabs/nursing_tab.dart';
import 'package:staff_mate/tabs/investigation_tab.dart';

class PatientActionBottomSheet extends StatefulWidget {
  final Patient patient;
  final int initialIndex;

  const PatientActionBottomSheet({
    super.key, 
    required this.patient, 
    this.initialIndex = 0
  });

  @override
  State<PatientActionBottomSheet> createState() => _PatientActionBottomSheetState();
}

class _PatientActionBottomSheetState extends State<PatientActionBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // --- 1. Header with Patient Info ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        widget.patient.patientname.isNotEmpty ? widget.patient.patientname[0] : "P", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patient.patientname, 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          Text(
                            // Assuming patient model has bedname, otherwise handle null
                            "Dr. Avinash Gupta • ${widget.patient.bedname}", 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close), 
                      onPressed: () => Navigator.pop(context)
                    )
                  ],
                ),
              ),
              
              // --- 2. Tab Bar ---
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1A237E),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1A237E),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: "Prescription"),
                  Tab(text: "Nursing Care"),
                  Tab(text: "Investigation"),
                ],
              ),

              // --- 3. Tab Views (Content) ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // We pass the scroll controller so the sheet scrolls naturally
                    MedicineListTab(scrollController: controller, patientId: widget.patient.clientId),
                    NursingListTab(scrollController: controller),
                    InvestigationListTab(scrollController: controller),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}