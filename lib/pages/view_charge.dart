import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/models/patient.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HospitalChargeScreen(),
  ));
}

class HospitalChargeScreen extends StatefulWidget {
  const HospitalChargeScreen({super.key, Patient? patient});

  @override
  State<HospitalChargeScreen> createState() => _HospitalChargeScreenState();
}

class _HospitalChargeScreenState extends State<HospitalChargeScreen> {
  // Controllers for the Date Fields
  final TextEditingController _fromDateController = TextEditingController(text: "24/12/2025");
  final TextEditingController _toDateController = TextEditingController(text: "24/12/2025");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Patient Invoice View", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Filter Section (Dates + Button)
              _buildFilterSection(context),
              
              const SizedBox(height: 20),
              
              // 2. Data Table Section
              _buildDataTable(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget: Filter Section ---
  Widget _buildFilterSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive check: if screen is narrow, stack elements, otherwise row
        bool isWide = constraints.maxWidth > 600;
        
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 15, // Horizontal space between elements
          runSpacing: 15, // Vertical space if they wrap
          children: [
            _buildDateInput(context, "from Date", _fromDateController),
            _buildDateInput(context, "To Date", _toDateController),
            
            // View Button
            SizedBox(
              height: 45, // Match height of text fields roughly
              child: ElevatedButton(
                onPressed: () {
                  // Add filter logic here
                  print("View clicked: ${_fromDateController.text} to ${_toDateController.text}");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF198754), // Bootstrap Success Green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
                ),
                child: const Text(
                  "View",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  // --- Widget: Single Date Input Field ---
  Widget _buildDateInput(BuildContext context, String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with Red Asterisk
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
            children: const [
              TextSpan(text: "*", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Input Box
        SizedBox(
          width: 160,
          height: 45,
          child: TextField(
            controller: controller,
            readOnly: true, // Prevent manual typing
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF2F2F2), // Light grey background like screenshot
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none, // Remove outline
              ),
            ),
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setState(() {
                  controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  // --- Widget: Data Table ---
  Widget _buildDataTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        // Optional: Add a border around the whole table if desired
        // border: Border.all(color: Colors.grey.shade300),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFEEEEEE)), // Grey header
            dataRowColor: MaterialStateProperty.all(Colors.white),
            columnSpacing: 30,
            horizontalMargin: 10,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 13,
            ),
            dataTextStyle: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text("Sr no.")),
              DataColumn(label: Text("Invoice Id")),
              DataColumn(label: Text("Patient Name")),
              DataColumn(label: Text("Charge")),
              DataColumn(label: Text("Quantity")),
              DataColumn(label: Text("Total Amount")),
              DataColumn(label: Text("Requested By")),
              DataColumn(label: Text("Charge Name")),
              DataColumn(label: Text("Charge Date")),
            ],
            rows: [
              // Row 1 (From your Screenshot)
              DataRow(cells: [
                const DataCell(Text("1")),
                const DataCell(Text("354330")),
                const DataCell(Text("Mr. ADARSH PANDEY")),
                const DataCell(Text("10")),
                const DataCell(Text("1")),
                const DataCell(Text("10")),
                const DataCell(Text("Sakshimuley")),
                DataCell(
                  Container(
                    width: 200, // Constrain width for long text
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      "CATH CONSUMABLE\nDr. A. YAGNESHWAR SHARMA",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const DataCell(Text("24-12-2025")),
              ]),
              // Example Row 2 (To show striping or list effect)
              /*
              DataRow(cells: [
                DataCell(Text("2")),
                DataCell(Text("354331")),
                DataCell(Text("Mr. ADARSH PANDEY")),
                DataCell(Text("500")),
                DataCell(Text("1")),
                DataCell(Text("500")),
                DataCell(Text("Admin")),
                DataCell(Text("Consultation Fee")),
                DataCell(Text("24-12-2025")),
              ]),
              */
            ],
          ),
        ),
      ),
    );
  }
}