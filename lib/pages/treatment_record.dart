import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/models/patient.dart'; // Ensure this path is correct

class TreatmentRecordPage extends StatefulWidget {
  final Patient patient;
  const TreatmentRecordPage({super.key, required this.patient});

  @override
  State<TreatmentRecordPage> createState() => _TreatmentRecordPageState();
}

class _TreatmentRecordPageState extends State<TreatmentRecordPage> {
  // UI Controllers
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  
  // Equipment Controllers
  final TextEditingController _equipNameController = TextEditingController();
  final TextEditingController _equipModeController = TextEditingController();
  final TextEditingController _equipLtrController = TextEditingController();

  // Colors based on reference
  final Color darkBlue = const Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(now);
    _toDateController.text = DateFormat('yyyy-MM-dd').format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          // 1. Modern Header
          _buildModernHeader(),

          // 2. Date Filter Section (Floating Card)
          Transform.translate(
            offset: const Offset(0, -20),
            child: _buildDateFilterSection(),
          ),

          // 3. Scrollable Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- CLINICAL SECTIONS ---
                  _buildSectionLabel("Clinical Care"),
                  
                  _buildExpandableSection(
                    title: "Medicine Care",
                    icon: Icons.medication,
                    child: _buildCardList(
                      // Example Data Structure
                      items: [], 
                      labels: ["Medicine", "Qty", "Freq", "Instruction", "Time"],
                      emptyMessage: "No Medicine Records"
                    ),
                  ),

                  _buildExpandableSection(
                    title: "Investigation",
                    icon: Icons.biotech,
                    child: _buildInvestigationView(),
                  ),

                  _buildExpandableSection(
                    title: "Nursing Care",
                    icon: Icons.local_hospital,
                    child: _buildCardList(
                      items: [],
                      labels: ["Care Type", "Notes"],
                      emptyMessage: "No Nursing Care Records"
                    ),
                  ),

                  _buildExpandableSection(
                    title: "Dietary Care",
                    icon: Icons.restaurant,
                    child: _buildDietaryView(),
                  ),

                   _buildExpandableSection(
                    title: "Vitals",
                    icon: Icons.monitor_heart,
                    child: _buildVitalsView(),
                  ),

                   _buildExpandableSection(
                    title: "Nursing Care Plan",
                    icon: Icons.assignment,
                    child: _buildCardList(
                      items: [],
                      labels: ["Subjective", "Objective", "Diagnosis", "Plan"],
                      emptyMessage: "No Care Plan"
                    ),
                  ),

                  _buildExpandableSection(
                    title: "Medication Chart",
                    icon: Icons.list_alt,
                    child: _buildCardList(
                      items: [],
                      labels: ["Medicine", "Freq", "Route", "Given By"],
                      emptyMessage: "No Chart Data"
                    ),
                  ),

                  // --- ADMINISTRATIVE SECTIONS ---
                  const SizedBox(height: 20),
                  _buildSectionLabel("Administrative & Others"),

                  _buildExpandableSection(
                    title: "Consultant Visited",
                    icon: Icons.person_pin,
                    child: _buildCardList(
                      items: [],
                      labels: ["Doctor", "Time", "Fees", "Status"],
                      emptyMessage: "No Visits"
                    ),
                  ),

                  _buildExpandableSection(
                    title: "Request Time",
                    icon: Icons.access_time,
                    child: _buildCardList(
                      items: [],
                      labels: ["Group", "Unit", "Allotted"],
                      emptyMessage: "No Request Data"
                    ),
                  ),

                   _buildExpandableSection(
                    title: "Transfer Advice",
                    icon: Icons.move_up,
                    child: _buildCardList(
                      items: [],
                      labels: ["To Ward/Bed", "From", "To"],
                      emptyMessage: "No Transfers"
                    ),
                  ),

                  // --- EQUIPMENT SECTION (With Inputs) ---
                  const SizedBox(height: 20),
                  _buildSectionLabel("Equipment & Inventory"),
                  _buildEquipmentSection(),

                  const SizedBox(height: 20),
                  _buildSectionLabel("Notes"),
                   _buildExpandableSection(
                    title: "Day to Day Notes",
                    icon: Icons.note_alt,
                    isExpanded: true, // Auto open notes
                    child: _buildCardList(
                      items: [],
                      labels: ["Date", "Note", "By"],
                      emptyMessage: "No Day Notes found."
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. HEADER WIDGETS ---

  Widget _buildModernHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 35 // Extra padding for the overlapping card
      ),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 15),
              Text("Treatment Record", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Patient Info Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.patient.patientname, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("UHID: ${widget.patient.ipdNo}", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text("${widget.patient.ward}/${widget.patient.bedname}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text("${widget.patient.age} Y / ${widget.patient.gender}", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateInput("From Date", _fromDateController),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateInput("To Date", _toDateController),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("View Record", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.print, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: darkBlue,
                    side: BorderSide(color: darkBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: Text("Print", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDateInput(String label, TextEditingController controller) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: darkBlue),
              ),
              child: child!,
            );
          }
        );
        if(picked != null) setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: darkBlue),
                const SizedBox(width: 8),
                Text(controller.text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(), 
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0)
      ),
    );
  }

  Widget _buildExpandableSection({required String title, required IconData icon, required Widget child, bool isExpanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: darkBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: darkBlue, size: 20),
          ),
          title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          childrenPadding: const EdgeInsets.all(16),
          children: [child],
        ),
      ),
    );
  }

  // Generic Card List for Data
  Widget _buildCardList({required List<List<String>> items, required List<String> labels, required String emptyMessage}) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        width: double.infinity,
        decoration: BoxDecoration(color: bgGrey, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(Icons.folder_open, color: Colors.grey[400], size: 30),
            const SizedBox(height: 8),
            Text(emptyMessage, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: items.map((row) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!)
          ),
          child: Column(
            children: List.generate(row.length, (index) {
              if (index >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90, 
                      child: Text(labels[index], style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))
                    ),
                    Expanded(
                      child: Text(row[index], style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87))
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }

  // --- 3. SPECIALIZED VIEWS ---

  Widget _buildVitalsView() {
    // Vitals are a matrix (Time vs Field). Best viewed as a horizontal scrollable card on mobile.
    List<String> timeHeaders = ["10:00", "14:00", "18:00", "22:00"];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8)
        ),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(bgGrey),
          columnSpacing: 20,
          columns: [
             DataColumn(label: Text("Vital", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
             ...timeHeaders.map((e) => DataColumn(label: Text(e, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)))),
          ],
          rows: [
            // Example Rows
            _buildVitalRow("Temp", ["98.6", "99.1", "-", "-"]),
            _buildVitalRow("BP", ["120/80", "118/78", "-", "-"]),
            _buildVitalRow("Pulse", ["72", "75", "-", "-"]),
          ],
        ),
      ),
    );
  }

  DataRow _buildVitalRow(String name, List<String> values) {
    return DataRow(cells: [
      DataCell(Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12))),
      ...values.map((v) => DataCell(Text(v, style: GoogleFonts.poppins(fontSize: 12)))),
    ]);
  }

  Widget _buildDietaryView() {
    // Grouped List for Diet
    return Column(
      children: [
        _buildDetailRow("Breakfast", "Oats, Milk (200ml)"),
        const Divider(),
        _buildDetailRow("Lunch", "Dal, Rice, Curd"),
        const Divider(),
        _buildDetailRow("Dinner", "Soup, Bread"),
      ],
    );
  }

  Widget _buildInvestigationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTag("Pathology", Colors.orange),
        const SizedBox(height: 5),
        _buildDetailRow("CBC", "Pending"),
        _buildDetailRow("Lipid Profile", "Completed"),
        const SizedBox(height: 10),
        _buildTag("Radiology", Colors.blue),
        const SizedBox(height: 5),
        _buildDetailRow("X-Ray Chest", "Completed"),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- 4. EQUIPMENT INPUT SECTION ---

  Widget _buildEquipmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Add Equipment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
          const SizedBox(height: 12),
          _buildModernInput(controller: _equipNameController, label: "Name", icon: Icons.medical_services),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildModernInput(controller: _equipModeController, label: "Mode", icon: Icons.settings)),
              const SizedBox(width: 10),
              Expanded(child: _buildModernInput(controller: _equipLtrController, label: "Ltr/Flow", icon: Icons.water_drop)),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Add logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: darkBlue,
                side: BorderSide(color: darkBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Add Equipment +", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // List of added equipment (Mini Table)
          _buildCardList(
            items: [], // Populate this list
            labels: ["Name", "Mode", "Ltr"],
            emptyMessage: "No Equipment Added"
          )
        ],
      ),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: bgGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 16),
              border: InputBorder.none,
              isDense: true,
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}