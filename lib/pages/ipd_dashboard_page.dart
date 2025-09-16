import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/dashboard_data.dart';
import 'package:staff_mate/models/patient.dart';

class IpdDashboardPage extends StatefulWidget {
  const IpdDashboardPage({super.key});

  @override
  State<IpdDashboardPage> createState() => _IpdDashboardPageState();
}

class _IpdDashboardPageState extends State<IpdDashboardPage> {
  final IpdService ipdService = IpdService();
  Future<IpdDashboardData>? _dashboardDataFuture;

  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];

  final TextEditingController _searchController = TextEditingController();

  String _selectedFilterCategory = 'Inhouse Patients';
  String? _selectedWard = 'All Ward';
  String _selectedStatus = 'Active';
  String _selectedCategory = 'Format1';
  DateTimeRange? _selectedDateRange;

  final List<String> wardOptions = [
    'All Ward', 'GEN', 'ICU', 'CathLab ICU', 'Isolation', 'Post-Ops',
    'Twin Sharing', 'DLX', 'Suite', 'BMT', 'Casuality', 'Day Care', 'MBS'
  ];
  final List<String> statusOptions = ['Active', 'Inactive'];
  final List<String> categoryOptions = ['Format1', 'Free Case'];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    // just call service, no need to fetch session here anymore
    setState(() {
      _dashboardDataFuture = ipdService.fetchDashboardData();
    });
  }

  void _filterPatients() {
    List<Patient> tempPatients = List.from(_allPatients);

    switch (_selectedFilterCategory) {
      case 'To be Discharged':
        tempPatients = tempPatients.where((p) => p.dischargeStatus != '0').toList();
        break;
      case 'Excess Amount':
        tempPatients = tempPatients.where((p) => p.patientBalance > 0).toList();
        break;
      case 'MLC':
        tempPatients = tempPatients.where((p) => p.isMlc != '0').toList();
        break;
      case 'Self':
        tempPatients = tempPatients.where((p) => p.party.toLowerCase().contains('self')).toList();
        break;
      case 'TP':
        tempPatients = tempPatients.where(
            (p) => p.party.toLowerCase().contains('third party') && !p.party.toLowerCase().contains('corporate')).toList();
        break;
      case 'TP Corporate':
        tempPatients = tempPatients.where((p) => p.party.toLowerCase().contains('corporate')).toList();
        break;
      default:
        break;
    }

    if (mounted) {
      setState(() {
        _filteredPatients = tempPatients.where((p) {
          final wardMatch = _selectedWard == 'All Ward' || p.ward == _selectedWard;
          bool dateMatch = true;
          if (_selectedDateRange != null) {
            dateMatch = p.admissionDateTime.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                p.admissionDateTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          }
          final searchMatch = _searchController.text.isEmpty ||
              p.patientname.toLowerCase().contains(_searchController.text.toLowerCase()) ||
              p.ipdNo.toLowerCase().contains(_searchController.text.toLowerCase()) ||
              p.practitionername.toLowerCase().contains(_searchController.text.toLowerCase()) ||
              p.ward.toLowerCase().contains(_searchController.text.toLowerCase());

          return wardMatch && dateMatch && searchMatch;
        }).toList();
      });
    }
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _filterPatients();
    }
  }

  void _showPatientDetailsDialog(Patient patient) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(patient.patientname, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.local_hospital_outlined, 'Ward | Bed No:', '${patient.ward} | ${patient.bedname}'),
              _buildDetailRow(Icons.person_outline, 'Consultant Name:', patient.practitionername),
              _buildDetailRow(Icons.calendar_today_outlined, 'Admission Date:',
                  DateFormat('dd-MM-yyyy HH:mm').format(patient.admissionDateTime)),
              _buildDetailRow(Icons.money, 'Patient Balance:', '₹${patient.patientBalance}'),
              _buildDetailRow(Icons.info_outline, 'IPD No:', patient.ipdNo),
              _buildDetailRow(Icons.credit_card, 'Party:', patient.party),
              _buildDetailRow(Icons.perm_identity, 'Age/Gender:', '${patient.age}Y / ${patient.gender.toUpperCase()}'),
              _buildDetailRow(Icons.logout, 'Discharge Status:',
                  patient.dischargeStatus == '0' ? 'Not Discharged' : 'Discharged'),
              _buildDetailRow(Icons.medical_services_outlined, 'MLC:', patient.isMlc == '0' ? 'No' : 'Yes'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pop(); // Close the current dialog
              _showAddOptionsDialog(context); // Open the new dialog with 4 boxes
            },
          ),
        ],
      ),
    );
  }

  void _showAddOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Add New Request', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionBox(context, 'Req Prescription'),
            _buildOptionBox(context, 'Req Investigation'),
            _buildOptionBox(context, 'Req Nursing Care'),
            _buildOptionBox(context, 'Req Consultant'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionBox(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        // Handle tap for each option, e.g., navigate to a new screen or show a specific form
        Navigator.of(context).pop(); // Close the add options dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You tapped on $title')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.indigo),
          ),
        ),
      ),
    );
  }


  void _showStatDetailsDialog(String title, String value) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Value: $value", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Icon(Icons.notifications_none, color: Colors.indigo, size: 28),
                Icon(Icons.flag_outlined, color: Colors.indigo, size: 28),
                Icon(Icons.favorite_border, color: Colors.indigo, size: 28),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigo),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatCardColor(String title) {
    switch (title) {
      case 'Excess Amount':
        return const Color(0xFF303F9F);
      case 'Inhouse Patients':
        return const Color(0xFF795548);
      case 'Total Bed':
        return const Color(0xFF1976D2);
      case 'Available':
        return const Color(0xFF00796B);
      case 'Self':
        return const Color(0xFF455A64);
      case 'MLC':
        return const Color(0xFFC62828);
      case 'TP':
        return const Color(0xFF2E7D32);
      case 'TP Corporate':
        return const Color(0xFF6A1B9A);
      case 'To be Discharged':
        return const Color(0xFF9E9D24);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text('IPD Dashboard',
            style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600)),
        leading: const Icon(Icons.home_outlined, color: Colors.black54),
      ),
      body: FutureBuilder<IpdDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.patients.isEmpty) {
            return const Center(child: Text("No patient data available."));
          }

          final dashboardData = snapshot.data!;
          if (_allPatients.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _allPatients = dashboardData.patients;
                _filterPatients();
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatsGrid(dashboardData.statistics),
                const SizedBox(height: 16),
                _buildFilterSection(),
                const SizedBox(height: 16),
                _buildPatientGrid(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, int> statistics) {
    final statTitles = [
      'Excess Amount',
      'Inhouse Patients',
      'Total Bed',
      'Available',
      'Self',
      'MLC',
      'TP',
      'TP Corporate',
      'To be Discharged',
    ];

    Widget buildTappableStatCard(String title) {
      final value = statistics[title] ?? 0;
      final isSelected = _selectedFilterCategory == title;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedFilterCategory = title;
            });
            _filterPatients();
            _showStatDetailsDialog(title, value.toString());
          },
          child: StatCard(
            title: title,
            value: value.toString(),
            color: _getStatCardColor(title),
            isSelected: isSelected,
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: statTitles.sublist(0, 5).map(buildTappableStatCard).toList()),
        const SizedBox(height: 8),
        Row(children: statTitles.sublist(5, 9).map(buildTappableStatCard).toList()),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Patient, IPD No, Doctor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildDropdown(
                        value: _selectedWard,
                        items: wardOptions,
                        onChanged: (val) {
                          setState(() => _selectedWard = val);
                          _filterPatients();
                        })),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildDropdown(
                        value: _selectedStatus,
                        items: statusOptions,
                        onChanged: (val) {
                          setState(() => _selectedStatus = val!);
                          _filterPatients();
                        })),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildDropdown(
                        value: _selectedCategory,
                        items: categoryOptions,
                        onChanged: (val) {
                          setState(() => _selectedCategory = val!);
                          _filterPatients();
                        })),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.indigo),
                  onPressed: _selectDateRange,
                  tooltip: 'Filter by Admission Date',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      {required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPatientGrid() {
    if (_filteredPatients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text("No patients found matching your criteria.", style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 1.0,
      ),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showPatientDetailsDialog(_filteredPatients[index]),
          child: PatientGridCard(patient: _filteredPatients[index]),
        );
      },
    );
  }
}

// --------------------- StatCard ---------------------
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isSelected;

  const StatCard(
      {super.key, required this.title, required this.value, required this.color, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected ? const BorderSide(color: Colors.black, width: 2.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

// --------------------- PatientGridCard ---------------------
class PatientGridCard extends StatelessWidget {
  final Patient patient;

  const PatientGridCard({super.key, required this.patient});

  Color _getCardColor() {
    if (patient.dischargeStatus != '0') return const Color(0xFF9E9D24);
    if (patient.isMlc != '0') return const Color(0xFFC62828);
    if (patient.party.toLowerCase().contains('corporate')) return const Color(0xFF6A1B9A);
    if (patient.party.toLowerCase().contains('third party')) return const Color(0xFF2E7D32);
    if (patient.party.toLowerCase().contains('self')) return const Color(0xFF455A64);
    if (patient.patientBalance > 0) return const Color(0xFF303F9F);
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      clipBehavior: Clip.antiAlias,
      color: _getCardColor(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.patientname,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${patient.ward} | ${patient.bedname}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('IPD No: ${patient.ipdNo}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.notifications_none, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Icon(Icons.flag_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Icon(Icons.favorite_border, color: Colors.white, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
