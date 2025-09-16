import 'package:flutter/material.dart';
import 'package:staff_mate/widgets/capture_vitals_sheet.dart';
import 'package:staff_mate/pages/view_vitals_page.dart'; // ✅ Import the page

class NursePage extends StatelessWidget {
  const NursePage({super.key});

  @override   
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nurse Dashboard"),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildOption(
            context,
            Icons.monitor_heart,
            "Capture Vitals",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CaptureVitalsSheet(patientName: "John Doe"),
                ),
              );
            },
          ),
          _buildOption(
            context,
            Icons.visibility,
            "View Vitals", // ✅ New option
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViewVitalsPage(),
                ),
              );
            },
          ),
          _buildOption(
              context, Icons.medical_services, "Request Prescription", () {}),
          _buildOption(context, Icons.people, "Consultant", () {}),
          _buildOption(context, Icons.receipt, "Invoice / Add Charges", () {}),
          _buildOption(context, Icons.restaurant_menu, "Diet Plan", () {}),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 26),
        onTap: onTap,
      ),
    );
  }
}
