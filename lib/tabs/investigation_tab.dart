import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InvestigationListTab extends StatelessWidget {
  final ScrollController scrollController;
  
  const InvestigationListTab({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildInvestCard("CBC (Complete Blood Count)", "Sample Collected", Colors.orange),
        _buildInvestCard("Chest X-Ray PA View", "Report Ready", Colors.green),
        _buildInvestCard("Serum Creatinine", "Requested", Colors.blue),
      ],
    );
  }

  Widget _buildInvestCard(String name, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM, hh:mm a').format(DateTime.now()), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          )
        ],
      ),
    );
  }
}