import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/dashboard_data.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/pages/req_pres.dart';
import 'package:staff_mate/pages/req_inve.dart';

class IpdDashboardPage extends StatefulWidget {
  const IpdDashboardPage({super.key});

  @override
  State<IpdDashboardPage> createState() => _IpdDashboardPageState();
}

class _IpdDashboardPageState extends State<IpdDashboardPage> {
  final IpdService ipdService = IpdService();
  late Future<IpdDashboardData> _dashboardDataFuture;

  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilterCategory;
  String _selectedWard = 'All Ward';
  String _selectedStatus = 'Active';
  String _selectedCategory = 'Format1';
  DateTimeRange? _selectedDateRange;

  final List<String> wardOptions = [
    'All Ward',
    'GEN',
    'ICU',
    'CathLab ICU',
    'Isolation',
    'Post-Ops',
    'Twin Sharing',
    'DLX',
    'Suite',
    'BMT',
    'Casuality',
    'Day Care',
    'MBS',
  ];
  final List<String> statusOptions = ['Active', 'Inactive'];
  final List<String> categoryOptions = ['Format1', 'Free Case'];

  // counters
  int avaLen = 0,
      tpLen = 0,
      pTpLen = 0,
      mlcLen = 0,
      selfLen = 0,
      totalBed = 0,
      dischargeLen = 0,
      exceedLen = 0,
      inhouseLen = 0;
  bool bedCountLoading = false;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = ipdService.fetchDashboardData();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients() {
    List<Patient> tempPatients = List.from(_allPatients);

    // Filter out patients with empty ward and N/A beds - MUST have active bed
    tempPatients.removeWhere(
      (p) =>
          p.ward.isEmpty ||
          p.ward.toUpperCase() == "N/A" ||
          p.bedname.toUpperCase() == "N/A" ||
          p.bedname.isEmpty ||
          p.active != 1, // ONLY show active patients (admitted to bed)
    );

    debugPrint(
      'Total ACTIVE patients after filtering N/A: ${tempPatients.length}',
    );

    // Apply filter categories
    switch (_selectedFilterCategory) {
      case 'To be Discharged':
        tempPatients = tempPatients
            .where((p) => p.dischargeStatus != '0')
            .toList();
        break;
      case 'Excess Amount':
        tempPatients = tempPatients.where((p) => p.patientBalance > 0).toList();
        break;
      case 'MLC':
        tempPatients = tempPatients.where((p) => p.isMlc != '0').toList();
        break;
      case 'Self':
        tempPatients = tempPatients
            .where(
              (p) =>
                  p.active == 1 &&
                  p.isMlc == '0' &&
                  p.isPrivateTp == '0' &&
                  p.dischargeStatus == '0' &&
                  p.party == 'Self' &&
                  p.isUnderMaintenance == 0,
            )
            .toList();
        break;
      case 'TP':
        tempPatients = tempPatients
            .where(
              (p) =>
                  p.active == 1 &&
                  p.isMlc == '0' &&
                  p.isPrivateTp == '0' &&
                  p.dischargeStatus == '0' &&
                  p.party == 'Third Party' &&
                  p.isUnderMaintenance == 0,
            )
            .toList();
        break;
      case 'TP Corporate':
        tempPatients = tempPatients
            .where(
              (p) =>
                  p.active == 1 &&
                  p.party.toLowerCase().contains('corporate') &&
                  p.isUnderMaintenance == 0,
            )
            .toList();
        break;
      default:
        break;
    }

    // Apply ward, date range, and search filters
    _filteredPatients = tempPatients.where((p) {
      final wardMatch = _selectedWard == 'All Ward' || p.ward == _selectedWard;

      bool dateMatch = true;
      if (_selectedDateRange != null) {
        dateMatch =
            p.admissionDateTime.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            p.admissionDateTime.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }

      final searchMatch =
          _searchController.text.isEmpty ||
          p.patientname.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          p.ipdNo.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          p.practitionername.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          p.ward.toLowerCase().contains(_searchController.text.toLowerCase());

      return wardMatch && dateMatch && searchMatch;
    }).toList();

    // Sort by bedid
    _filteredPatients.sort((a, b) => a.bedid.compareTo(b.bedid));

    debugPrint(
      'Filtered patients count after all filters: ${_filteredPatients.length}',
    );

    // Only call setState if not already in build phase
    if (mounted) {
      setState(() {});
    }
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      _selectedDateRange = picked;
      _filterPatients();
    }
  }

  Future<void> _showPatientDetailsDialog(Patient patient) async {
    // Print patient details to terminal when clicked
    debugPrint('========================================');
    debugPrint('PATIENT CLICKED: ${patient.patientname}');
    debugPrint('========================================');
    debugPrint('IPD No: ${patient.ipdNo}');
    debugPrint('Ward: ${patient.ward}');
    debugPrint('Bed: ${patient.bedname}');
    debugPrint('Bed ID: ${patient.bedid}');
    debugPrint('Doctor: ${patient.practitionername}');
    debugPrint('admissionId: ${patient.admissionId}');
    debugPrint('Admission Date: ${DateFormat('dd-MM-yyyy HH:mm').format(patient.admissionDateTime)}');
    debugPrint('Age: ${patient.age} | Gender: ${patient.gender}');
    debugPrint('Party: ${patient.party}');
    debugPrint('Balance: ₹${patient.patientBalance}');
    debugPrint('MLC: ${patient.isMlc == '0' ? 'No' : 'Yes'}');
    debugPrint('Discharge Status: ${patient.dischargeStatus == '0' ? 'Not Discharged' : 'Discharged'}');
    debugPrint('Active: ${patient.active}');
    debugPrint('UHID: ${patient.uhid}');
    // debugPrint('Contact: ${patient.contactNumber}');
    // debugPrint('Address: ${patient.address}');
    debugPrint('========================================\n');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admissionid', patient.admissionId);
    await prefs.setString('patientid', patient.clientId);
    await prefs.setString('practitionerid', patient.practitionerid);

debugPrint('clientId : ${patient.clientId}');
debugPrint('practitionerid : ${patient.practitionerid}');


    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(125),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          patient.patientname,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                Icons.local_hospital_outlined,
                'Ward | Bed No:',
                '${patient.ward} | ${patient.bedname}',
              ),
              _buildDetailRow(
                Icons.person_outline,
                'Consultant Name:',
                patient.practitionername,
              ),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Admission Date:',
                DateFormat(
                  'dd-MM-yyyy HH:mm',
                ).format(patient.admissionDateTime),
              ),
              _buildDetailRow(
                Icons.money,
                'Patient Balance:',
                '₹${patient.patientBalance}',
              ),
              _buildDetailRow(Icons.info_outline, 'IPD No:', patient.ipdNo),
              _buildDetailRow(Icons.credit_card, 'Party:', patient.party),
              _buildDetailRow(
                Icons.perm_identity,
                'Age/Gender:',
                '${patient.age}Y / ${patient.gender.toUpperCase()}',
              ),
              _buildDetailRow(
                Icons.logout,
                'Discharge Status:',
                patient.dischargeStatus == '0'
                    ? 'Not Discharged'
                    : 'Discharged',
              ),
              _buildDetailRow(
                Icons.medical_services_outlined,
                'MLC:',
                patient.isMlc == '0' ? 'No' : 'Yes',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pop();
              _showAddOptionsDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showAddOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(125),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Add New Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionBox(
              context,
              'Req Prescription',
              const ReqPrescriptionPage(patientName: ''),
            ),
            _buildOptionBox(
              context,
              'Req Investigation',
              const ReqInvestigationPage(patientName: ''),
            ),
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

  Widget _buildOptionBox(BuildContext context, String title, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.indigo,
            ),
          ),
        ),
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
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
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
        title: Text(
          'IPD Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
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

          // Initialize patients and stats once
          if (_allPatients.isEmpty) {
            _allPatients = snapshot.data!.patients;

            // FIRST: Filter out N/A beds from _allPatients before any processing
            _allPatients.removeWhere(
              (p) =>
                  p.ward.isEmpty ||
                  p.ward.toUpperCase() == "N/A" ||
                  p.bedname.toUpperCase() == "N/A" ||
                  p.bedname.isEmpty ||
                  p.active != 1, // ONLY keep active/admitted patients
            );

            debugPrint('\n========================================');
            debugPrint('IPD DASHBOARD - ADMITTED PATIENTS ONLY');
            debugPrint('========================================');
            debugPrint(
              'Total ADMITTED patients (N/A beds excluded): ${_allPatients.length}',
            );

            // Print only admitted patient names and basic info
            for (int i = 0; i < _allPatients.length; i++) {
              final p = _allPatients[i];
              debugPrint(
                '${i + 1}. ${p.patientname} | Ward: ${p.ward} | Bed: ${p.bedname} | IPD: ${p.ipdNo}',
              );
            }
            debugPrint('========================================\n');

            _calculateBedStats();

            // Calculate filtered patients without calling setState
            List<Patient> tempPatients = List.from(_allPatients);
            _filteredPatients = tempPatients;
            _filteredPatients.sort((a, b) => a.bedid.compareTo(b.bedid));

            debugPrint(
              'Patients displayed on screen: ${_filteredPatients.length}',
            );
            debugPrint('========================================\n');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatsGrid(),
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

  // ---------------- Stats Grid ----------------
  Widget _buildStatsGrid() {
    final statData = {
      'Excess Amount': exceedLen,
      'Inhouse Patients': selfLen + mlcLen + tpLen + pTpLen + dischargeLen,
      'Total Bed': totalBed,
      'Available': avaLen,
      'Self': selfLen,
      'MLC': mlcLen,
      'TP': tpLen,
      'TP Corporate': pTpLen,
      'To be Discharged': dischargeLen,
    };

    return Column(
      children: [
        Row(
          children: statData.entries
              .toList()
              .sublist(0, 5)
              .map(
                (e) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilterCategory =
                            _selectedFilterCategory == e.key ? null : e.key;
                      });
                      _filterPatients();
                    },
                    child: StatCard(
                      title: e.key,
                      value: e.value.toString(),
                      color: _getStatCardColor(e.key),
                      isSelected: _selectedFilterCategory == e.key,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: statData.entries
              .toList()
              .sublist(5, 9)
              .map(
                (e) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilterCategory =
                            _selectedFilterCategory == e.key ? null : e.key;
                      });
                      _filterPatients();
                    },
                    child: StatCard(
                      title: e.key,
                      value: e.value.toString(),
                      color: _getStatCardColor(e.key),
                      isSelected: _selectedFilterCategory == e.key,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ---------------- Filter Section ----------------
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                      setState(() {
                        _selectedWard = val!;
                      });
                      _filterPatients();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: _selectedStatus,
                    items: statusOptions,
                    onChanged: (val) {
                      setState(() {
                        _selectedStatus = val!;
                      });
                      _filterPatients();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: _selectedCategory,
                    items: categoryOptions,
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val!;
                      });
                      _filterPatients();
                    },
                  ),
                ),
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

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
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
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ---------------- Patient Grid ----------------
  Widget _buildPatientGrid() {
    if (_filteredPatients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "No patients found matching your criteria.",
            style: TextStyle(fontSize: 16),
          ),
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

  // ---------------- Get Bed Values ----------------
  void _calculateBedStats() {
    avaLen = tpLen = pTpLen = mlcLen = selfLen = totalBed = dischargeLen =
        exceedLen = inhouseLen = 0;

    // Get unique beds for counting total beds (from already filtered data)
    List<Patient> dataForBeds = List.from(_allPatients);
    final seenBedIds = <dynamic>{};
    dataForBeds = dataForBeds.where((p) {
      if (seenBedIds.contains(p.bedid)) return false;
      seenBedIds.add(p.bedid);
      return true;
    }).toList();

    totalBed = seenBedIds.length;

    // Calculate statistics from admitted patients only (already filtered)
    List<Patient> data = List.from(_allPatients);

    for (var p in data) {
      if (p.active == 1 &&
          p.isMlc == '0' &&
          p.isPrivateTp == '0' &&
          p.dischargeStatus == '0' &&
          p.party == 'Third Party' &&
          p.isUnderMaintenance == 0) {
        tpLen++;
      }
      if (p.active == 1 &&
          p.dischargeStatus == '0' &&
          p.isMlc == '1' &&
          p.isUnderMaintenance == 0) {
        mlcLen++;
      }
      if (p.active == 1 &&
          p.isMlc == '0' &&
          p.isPrivateTp == '0' &&
          p.dischargeStatus == '0' &&
          p.party.toLowerCase() == 'self' &&
          p.isUnderMaintenance == 0) {
        selfLen++;
      }
      if (p.active == 1 &&
          p.dischargeStatus == '1' &&
          p.isUnderMaintenance == 0) {
        dischargeLen++;
      }
      if (p.active == 1 &&
          p.isPrivateTp == '1' &&
          p.dischargeStatus == '0' &&
          p.isUnderMaintenance == 0 &&
          p.party == 'Third Party') {
        pTpLen++;
      }
      if (p.dischargeStatus == '0') inhouseLen++;
      if (p.active == 0 && p.isUnderMaintenance == 0) avaLen++;
      if (p.patientBalance > 0) exceedLen++;
    }

    debugPrint(
      'Stats - Occupied Beds: $totalBed, Available: $avaLen, Self: $selfLen, TP: $tpLen, MLC: $mlcLen, Discharge: $dischargeLen',
    );
  }
}

// --------------------- StatCard ---------------------
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isSelected;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    final cardWidth = isTablet ? screenWidth / 6 - 8 : screenWidth / 3 - 12;
    final cardHeight = isTablet ? 100.0 : 80.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? const BorderSide(color: Colors.black, width: 2.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 20 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
    if (patient.party.toLowerCase().contains('corporate')) {
      return const Color(0xFF6A1B9A);
    }
    if (patient.party.toLowerCase().contains('third party')) {
      return const Color(0xFF2E7D32);
    }
    if (patient.party.toLowerCase() == 'self') return const Color(0xFF455A64);
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
                Text(
                  patient.patientname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${patient.ward} | ${patient.bedname}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'IPD No: ${patient.ipdNo}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
