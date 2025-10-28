import 'package:flutter/material.dart';
import 'package:staff_mate/pages/req_inve.dart';
import 'package:staff_mate/pages/req_pres.dart';
// import 'package:staff_mate/pages/req_nursing.dart';
// import 'package:staff_mate/pages/req_consultant.dart';

class PatientRequestPage extends StatelessWidget {
  final String patientName; // ✅ from API

  const PatientRequestPage({super.key, required this.patientName});

  static const Color primaryDarkBlue = Color(0xFF1A2C42);
  static const Color midDarkBlue = Color(0xFF273F5A);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  
  get patient => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreyColor,
      appBar: AppBar(
        backgroundColor: primaryDarkBlue,
        title: Text(
          "Patient Requests - $patientName",
          style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: whiteColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRequestCard(
              Icons.description,
              "Request Prescription",
             ReqPrescriptionPage(patientName: patientName),
              context,
            ),
           _buildRequestCard(
  Icons.science,
  "Request Investigation",
  ReqInvestigationPage(
    patientName: patientName,
    patient: patient,
  ),
  context,
),
            // _buildRequestCard(
            //   Icons.local_hospital,
            //   "Request Nursing Care",
            //   ReqNursingPage(patientName: patientName),
            //   context,
            // ),
            // _buildRequestCard(
            //   Icons.people,
            //   "Request Consultant",
            //   ReqConsultantPage(patientName: patientName),
            //   context,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    IconData icon,
    String title,
    Widget page,
    BuildContext context,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: whiteColor,
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accentTeal,
          child: Icon(icon, color: whiteColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: midDarkBlue),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }
}
