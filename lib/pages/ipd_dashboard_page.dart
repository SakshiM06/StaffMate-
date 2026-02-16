import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/dashboard_data.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/pages/req_pres.dart';
import 'package:staff_mate/pages/req_inve.dart';
import 'package:staff_mate/pages/shift_patient.dart';
import 'package:staff_mate/services/clinic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart'; 
import 'package:staff_mate/pages/notification_details.dart';
import 'package:staff_mate/services/user_information_service.dart'; 
import 'package:staff_mate/pages/vitals_page.dart';
import 'package:staff_mate/pages/day_to_day_notes.dart';
import 'package:staff_mate/pages/upload_doc.dart';

class IpdDashboardPage extends StatefulWidget {
  const IpdDashboardPage({super.key});

  @override
  State<IpdDashboardPage> createState() => _IpdDashboardPageState();
}

class _IpdDashboardPageState extends State<IpdDashboardPage> {
  final IpdService ipdService = IpdService();
  final ClinicService clinicService = ClinicService();
  
  late Future<IpdDashboardData> _dashboardDataFuture;
  List<dynamic> _practitionerList = [];
  List<dynamic> _specializationList = [];
  List<dynamic> _wardList = [];

  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilterCategory;
  String _selectedWard = 'All Ward';
  String _selectedStatus = 'Active';
  String _selectedCategory = 'Format1';
  DateTimeRange? _selectedDateRange;

  final List<String> _wardOptions = ['All Ward'];
  final List<String> statusOptions = ['Active', 'Inactive'];
  final List<String> categoryOptions = ['Format1', 'Free Case'];

  double _excessLimitAmount = 0.0;
  
  int avaLen = 0, tpLen = 0, pTpLen = 0,
      mlcLen = 0, selfLen = 0, totalBed = 0,
      dischargeLen = 0, exceedLen = 0, inhouseLen = 0;

  // Add user initial variable
  String userInitial = 'S';

  @override
  void initState() {
    super.initState();
    _loadExcessLimit();
    _refreshDashboardData();
    _searchController.addListener(_filterPatients);
    _fetchPractitionerList();
    _fetchSpecializationList();
    _fetchWardList();
    _loadUserInitial(); // Load user initial
  }

  // Method to load user initial
  Future<void> _loadUserInitial() async {
    try {
      final userInfo = await UserInformationService.getSavedUserInformation();
      if (userInfo.isNotEmpty) {
        String first = userInfo['firstName']?.toString() ?? '';
        String init = userInfo['initial']?.toString() ?? '';
        
        if (first.isNotEmpty) {
          setState(() {
            userInitial = first[0].toUpperCase();
          });
        } else if (init.isNotEmpty) {
          setState(() {
            userInitial = init[0].toUpperCase();
          });
        } else {
          String userId = userInfo['userId']?.toString() ?? '';
          if (userId.isNotEmpty) {
            setState(() {
              userInitial = userId[0].toUpperCase();
            });
          }
        }
      } else {
        final profileInfo = await UserInformationService.getUserProfileForDisplay();
        if (profileInfo.isNotEmpty) {
          String fullName = profileInfo['fullName'] ?? '';
          if (fullName.isNotEmpty) {
            setState(() {
              userInitial = fullName[0].toUpperCase();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user initial: $e');
    }
  }

  Future<void> _loadExcessLimit() async {
    try {
      _excessLimitAmount = await ClinicService.getExcessLimit();
    } catch (e) {
      _excessLimitAmount = 0.0;
    }
  }

  void _refreshDashboardData() {
    setState(() {
      String apiWardId = "0"; 
      _dashboardDataFuture = ipdService.fetchDashboardData(wardId: apiWardId).then((data) {
        _allPatients = data.patients.where((p) => 
          p.ward.isNotEmpty && p.ward != "N/A" && p.ward.toLowerCase() != "n/a"
        ).toList();
        _calculateBedStats();
        _filterPatients(); 
        return data;
      });
    });
  }

  Future<void> _fetchPractitionerList() async {
    try {
      final practitioners = await ipdService.fetchPractitionerList(
        branchId: "1", specializationId: 0, isVisitingConsultant: 1,
      );
      setState(() => _practitionerList = practitioners);
    } catch (e) { debugPrint('Error loading practitioner list: $e'); }
  }

  Future<void> _fetchSpecializationList() async {
    try {
      final specializations = await ipdService.fetchSpecializationList(branchId: "1");
      setState(() => _specializationList = specializations);
    } catch (e) { debugPrint('Error loading specialization list: $e'); }
  }

  Future<void> _fetchWardList() async {
    try {
      final wards = await ipdService.fetchBranchWardList(branchId: "1");
      setState(() {
        _wardList = wards;
        _wardOptions.clear();
        _wardOptions.add('All Ward');
        for (var ward in wards) {
          if (ward is Map<String, dynamic>) {
            final wardName = ward['wardname'] ?? ward['name'] ?? ward['wardName'] ?? '';
            if (wardName.isNotEmpty && wardName != "N/A" && wardName.toLowerCase() != "n/a") {
              _wardOptions.add(wardName);
            }
          }
        }
      });
    } catch (e) {
      setState(() {
        _wardOptions.addAll(['Emergency', 'Semi-pvt.', 'Pvt.', 'Casualty', 'GEN FEMALE', 'DLX', 'MICU', 'SICU', 'NICU', 'Isolation emergency', 'SUIT ROOM', 'OT Ward', 'Labour Room', 'HDU', 'CCU', 'CT ICU', 'General Ward (4F)']);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients() {
    List<Patient> tempPatients = List.from(_allPatients);
    
    final seenBedIds = <dynamic>{};
    tempPatients = tempPatients.where((p) => seenBedIds.add(p.bedid)).toList();
    tempPatients.sort((a, b) => a.bedid.compareTo(b.bedid));

    switch (_selectedFilterCategory) {
      case 'Available':
        tempPatients = tempPatients.where((p) => p.active == 0 && p.isUnderMaintenance == 0).toList();
        break;
      case 'To be Discharged':
        tempPatients = tempPatients.where((p) => p.dischargeStatus != '0' && p.dischargeStatus != '0.0').toList();
        break;
      case 'Excess Amount':
        tempPatients = tempPatients.where((p) {
          final balance = p.patientBalance ?? 0.0;
          return balance > 0 && balance > _excessLimitAmount;
        }).toList();
        break;
      case 'MLC':
        tempPatients = tempPatients.where((p) => p.isMlc != '0' && p.isMlc != '0.0').toList();
        break;
      case 'Self':
        tempPatients = tempPatients.where((p) => 
          p.active == 1 && 
          (p.isMlc == '0' || p.isMlc == '0.0') && 
          (p.dischargeStatus == '0' || p.dischargeStatus == '0.0') && 
          (p.isPrivateTp == '0' || p.isPrivateTp == '0.0') && 
          p.party.toLowerCase() == 'self' && 
          p.isUnderMaintenance == 0
        ).toList();
        break;
      case 'TP':
        tempPatients = tempPatients.where((p) => 
          p.active == 1 && 
          (p.isMlc == '0' || p.isMlc == '0.0') && 
          (p.dischargeStatus == '0' || p.dischargeStatus == '0.0') && 
          p.party.toLowerCase().contains('third party') && 
          !p.party.toLowerCase().contains('corporate') && 
          (p.isPrivateTp == '0' || p.isPrivateTp == '0.0') &&
          p.isUnderMaintenance == 0
        ).toList();
        break;
      case 'TP Corporate':
        tempPatients = tempPatients.where((p) => 
          p.active == 1 && 
          p.party.toLowerCase().contains('corporate') && 
          p.isUnderMaintenance == 0
        ).toList();
        break;
      case 'Inhouse Patients':
        tempPatients = tempPatients.where((p) => p.active == 1).toList();
        break;
      case 'Total Bed':
        break;
      default:
        tempPatients = tempPatients.where((p) => p.active == 1 || (p.active == 0 && p.isUnderMaintenance == 0)).toList();
        break;
    }

    _filteredPatients = tempPatients.where((p) {
      final wardMatch = _selectedWard == 'All Ward' || p.ward == _selectedWard;
      bool dateMatch = true;
      if (_selectedDateRange != null) {
        dateMatch = p.admissionDateTime.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    p.admissionDateTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }
      final searchText = _searchController.text.toLowerCase();
      final searchMatch = searchText.isEmpty ||
          p.patientname.toLowerCase().contains(searchText) ||
          p.ipdNo.toLowerCase().contains(searchText) ||
          p.practitionername.toLowerCase().contains(searchText) ||
          p.ward.toLowerCase().contains(searchText);
      return wardMatch && dateMatch && searchMatch;
    }).toList();

    if (mounted) setState(() {});
  }

  void _calculateBedStats() {
    avaLen = tpLen = pTpLen = mlcLen = selfLen = totalBed = dischargeLen = exceedLen = inhouseLen = 0;
    List<Patient> data = List.from(_allPatients);
    final seenBedIds = <dynamic>{};
    totalBed = data.where((p) => seenBedIds.add(p.bedid)).length;

    for (var p in data) {
      if (p.active == 0 && p.isUnderMaintenance == 0) {
        avaLen++;
      }
      if (p.active == 1) {
        inhouseLen++;
        if (p.party.toLowerCase().contains('corporate') && p.isUnderMaintenance == 0) {
          pTpLen++;
        }
        else if (p.active == 1 && (p.isMlc == '0' || p.isMlc == '0.0') && (p.dischargeStatus == '0' || p.dischargeStatus == '0.0') && p.party.toLowerCase().contains('third party') && !p.party.toLowerCase().contains('corporate') && (p.isPrivateTp == '0' || p.isPrivateTp == '0.0') && p.isUnderMaintenance == 0) {
          tpLen++;
        }
        if ((p.isMlc != '0' && p.isMlc != '0.0') && p.isUnderMaintenance == 0) {
          mlcLen++;
        }
        if ((p.isMlc == '0' || p.isMlc == '0.0') && (p.dischargeStatus == '0' || p.dischargeStatus == '0.0') && (p.isPrivateTp == '0' || p.isPrivateTp == '0.0') && p.party.toLowerCase() == 'self' && p.isUnderMaintenance == 0) {
          selfLen++;
        }
        if ((p.dischargeStatus != '0' && p.dischargeStatus != '0.0') && p.isUnderMaintenance == 0) {
          dischargeLen++;
        }
      }
      final balance = p.patientBalance ?? 0.0;
      if (balance > 0 && balance > _excessLimitAmount) {
        exceedLen++;
      }
    }
  }

  // void _openVitalsEntry(Patient patient) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => VitalsEntrySheet(patient: patient),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1A237E); 
    const Color bgGrey = Color(0xFFF5F7FA);

   return Scaffold(
  backgroundColor: bgGrey,
  body: Stack(
    children: [

      FutureBuilder<IpdDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_allPatients.isEmpty && snapshot.hasData && snapshot.data!.patients.isNotEmpty) {
            _allPatients = snapshot.data!.patients.where((p) => p.ward.isNotEmpty && p.ward != "N/A" && p.ward.toLowerCase() != "n/a").toList();
            _filteredPatients = List.from(_allPatients);
            _calculateBedStats();
            WidgetsBinding.instance.addPostFrameCallback((_) => _filterPatients());
          }

          return Column(
            children: [

              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10, bottom: 20),
                decoration: const BoxDecoration(
                  color: darkBlue,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("IPD Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Text(
                              userInitial,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search Patient, ID, Ward...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6), size: 18),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showFilterBottomSheet,
                            child: Container(
                              height: 40, width: 40,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.tune, color: darkBlue, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFittedStat("Total Beds", totalBed, Colors.blue.shade300),
                        _buildFittedStat("Available", avaLen, Colors.tealAccent.shade700),
                        _buildFittedStat("MLC", mlcLen, Colors.redAccent),
                        _buildFittedStat("Excess Amount", exceedLen, Colors.orangeAccent),
                        _buildFittedStat("To be Discharged", dischargeLen, Colors.yellow),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFittedStat("Inhouse", inhouseLen, Colors.brown),
                        _buildFittedStat("TP", tpLen, Colors.lightGreen.shade400),
                        _buildFittedStat("Self", selfLen, Colors.blueGrey.shade500),
                        _buildFittedStat("TP Corp", pTpLen, Colors.pink.shade200),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _filteredPatients.isEmpty && _allPatients.isNotEmpty
                    ? Center(child: Text("No patients found", style: GoogleFonts.poppins(color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          return PatientGridCardCompact(
                            patient: _filteredPatients[index],
                            excessLimit: _excessLimitAmount,
                            onCardTap: () => _showPatientQuickActionSheet(_filteredPatients[index]),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ],
  ),
);
  }
  
  Widget _buildFittedStat(String label, int count, Color color) {
    String filterKey = label;
    if(label == "Excess") filterKey = "Excess Amount";
    if(label == "Discharge") filterKey = "To be Discharged";
    if(label == "Total") filterKey = "Total Bed";
    if(label == "Inhouse") filterKey = "Inhouse Patients";
    if(label == "TP Corp") filterKey = "TP Corporate";

    bool isSelected = _selectedFilterCategory == filterKey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilterCategory = isSelected ? null : filterKey;
            _filterPatients();
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$count", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isSelected ? color : (label == "Inhouse" ? Colors.brown : color), fontSize: 14, height: 1)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9, color: isSelected ? Colors.black87 : Colors.white.withOpacity(0.8), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, height: 1)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    String tempSelectedWard = _selectedWard;
    String tempSelectedStatus = _selectedStatus;
    String tempSelectedCategory = _selectedCategory;
    DateTimeRange? tempSelectedDateRange = _selectedDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  Text("Filter Options", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                 
                  Text("Select Ward", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _wardOptions.map((ward) {
                              bool isSelected = tempSelectedWard == ward;
                              return ChoiceChip(
                                label: Text(ward),
                                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                                selected: isSelected,
                                selectedColor: const Color(0xFF1A237E),
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!)),
                                onSelected: (selected) { if (selected) setModalState(() => tempSelectedWard = ward); },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildDropdownLabel("Status"), _buildDropdown(value: tempSelectedStatus, items: statusOptions, onChanged: (val) => setModalState(() => tempSelectedStatus = val!))])),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildDropdownLabel("Category"), _buildDropdown(value: tempSelectedCategory, items: categoryOptions, onChanged: (val) => setModalState(() => tempSelectedCategory = val!))])),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(elevation:0, backgroundColor: Colors.grey[200], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => setModalState(() { tempSelectedWard = 'All Ward'; tempSelectedStatus = 'Active'; tempSelectedCategory = 'Format1'; tempSelectedDateRange = null; }), child: const Text("Reset"))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () { setState(() { _selectedWard = tempSelectedWard; _selectedStatus = tempSelectedStatus; _selectedCategory = tempSelectedCategory; _selectedDateRange = tempSelectedDateRange; }); Navigator.pop(context); _filterPatients(); }, child: const Text("Apply"))),
                  ])
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildDropdown({required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(), onChanged: onChanged)),
    );
  }

  void _showPatientQuickActionSheet(Patient patient) {
    if (patient.active == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bed ${patient.bedname} is Available")));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Text(patient.patientname[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
              title: Text(patient.patientname, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              subtitle: Text("${patient.ward} | Bed: ${patient.bedname}\nIPD: ${patient.ipdNo}", style: const TextStyle(fontSize: 12)),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("₹${patient.patientBalance}", style: TextStyle(fontWeight: FontWeight.bold, color: patient.patientBalance > 0 ? Colors.red : Colors.green)), const Text("Balance", style: TextStyle(fontSize: 10))]),
            ),
            const Divider(),
            
            // Replaced Wrap with horizontal ScrollView for single row responsive layout
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actionBtn(Icons.receipt, "Prescription", Colors.blue, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPrescriptionPage(patientName: patient.patientname, patient: patient))); 
                  }),
                  _actionBtn(Icons.science, "Investigation", Colors.orange, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReqInvestigationPage(patientName: patient.patientname, patient: patient))); 
                  }),
                  _actionBtn(Icons.assignment_outlined, "Records", Colors.teal, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TreatmentRecordWebViewPage(patient: patient))); 
                  }),
                  _actionBtn(Icons.favorite, "Vitals", Colors.redAccent, () { 
  Navigator.pop(context);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VitalsPage(patient: patient),
    ),
  );
}),
                  // _actionBtn(Icons.notifications_active, "Alert", Colors.amber, () { 
                  //   Navigator.pop(context);
                  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notification alert sent for ${patient.patientname}")));
                  // }),
                  _actionBtn(Icons.notifications_none, "Notifications", Colors.purple, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationDetailsPage(patientName: patient.patientname, patientId: patient.ipdNo,admissionId: patient.admissionId,)));
                  }),
                  _actionBtn(Icons.note_add, "Day-to-day Notes", Colors.brown, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DayToDayNotesPage(ipdId: patient.ipdNo, admissionDate: patient.admissionDate, patientName: patient.patientname, admissionId: patient.admissionId, patientId: '',)));
                  }),
                  _actionBtn(Icons.upload_file, "Upload Doc", Colors.green, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UploadDocScreen(patient: patient,)));
                  }),
                  _actionBtn(Icons.local_hospital, "Shift Patient", Colors.deepPurple, () { 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftPatientPage(patient: patient)));
                  }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
              child: Icon(icon, color: color, size: 22)
            ), 
            const SizedBox(height: 6), 
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500))
          ]
        ),
      ),
    );
  }
}

class PatientGridCardCompact extends StatelessWidget {
  final Patient patient;
  final double excessLimit;
  final VoidCallback onCardTap;
  
  const PatientGridCardCompact({
    super.key, 
    required this.patient, 
    required this.excessLimit,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isAvailable = patient.active == 0 && patient.isUnderMaintenance == 0;
    
    final balance = patient.patientBalance ?? 0.0;
    bool hasExcess = balance > 0 && balance > excessLimit;
    Color statusColor;
    String party = patient.party.toLowerCase();
    
    if (isAvailable) statusColor = Colors.tealAccent.shade700; 
    else if (patient.dischargeStatus != '0' && patient.dischargeStatus != '0.0') statusColor = Colors.yellow; 
    else if (patient.isMlc != '0' && patient.isMlc != '0.0') statusColor = Colors.redAccent;
    else if (hasExcess) statusColor = Colors.orangeAccent; 
    else if (party.contains('corporate')) statusColor = Colors.pink.shade200; 
    else if (party.contains('third party')) statusColor = Colors.lightGreen.shade400; 
    else if (party == 'self') statusColor = Colors.blueGrey.shade500;
    else statusColor = Colors.blue.shade300; 

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Container(color: statusColor.withOpacity(0.08)),
            Positioned(left: 0, top: 0, bottom: 0, width: 5, child: Container(color: statusColor)),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8), 
              child: isAvailable 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bed, color: statusColor, size: 24),
                      const SizedBox(height: 2),
                      Text(patient.bedname, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      Text("Avail", style: GoogleFonts.poppins(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 11, backgroundColor: statusColor.withOpacity(0.2), child: Text(patient.patientname.isNotEmpty ? patient.patientname[0] : "?", style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 6),
                        Expanded(child: Text(patient.bedname, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 6), 
                    Text(patient.patientname, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11)),
                    Text(patient.ward, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
                    Text("IPD: ${patient.ipdNo}", style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
            ),
          ],
        ),
      ),
    );   
  }
}


// class VitalsEntrySheet extends StatefulWidget {
//   final Patient patient;
//   const VitalsEntrySheet({super.key, required this.patient});

//   @override
//   State<VitalsEntrySheet> createState() => _VitalsEntrySheetState();
// }

// class _VitalsEntrySheetState extends State<VitalsEntrySheet> {
//   final TextEditingController _dateController = TextEditingController();
//   final TextEditingController _tempController = TextEditingController();
//   final TextEditingController _hrController = TextEditingController();
//   final TextEditingController _rrController = TextEditingController();
//   final TextEditingController _sysBpController = TextEditingController();
//   final TextEditingController _diaBpController = TextEditingController();
//   final TextEditingController _rbsController = TextEditingController();
//   final TextEditingController _spo2Controller = TextEditingController();
  
//   String _selectedHH = '00';
//   String _selectedMM = '00';
//   bool _isLoading = false;
//   String? _errorMessage;
//   List<Map<String, dynamic>> _vitalsMasterData = [];
//   final IpdService _ipdService = IpdService();
  
//   final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
//   final List<String> _minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));

//   static const Color darkBlue = Color(0xFF1A237E);
//   final Color bgGrey = const Color(0xFFF5F7FA);

//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     _dateController.text = DateFormat('yyyy-MM-dd').format(now); 
//     _selectedHH = now.hour.toString().padLeft(2, '0');
//     _selectedMM = now.minute.toString().padLeft(2, '0');
    
//     _loadVitalsMasterData();
//   }

//   Future<void> _loadVitalsMasterData() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final response = await _ipdService.fetchVitalsMasterData();
      
//       if (response['success'] == true) {
//         final List<dynamic> masterData = response['data'] ?? [];
        
//         _vitalsMasterData = masterData.map((item) {
//           if (item is Map<String, dynamic>) {
//             return item;
//           } else {
//             return <String, dynamic>{};
//           }
//         }).toList();
        
//         debugPrint('Loaded ${_vitalsMasterData.length} vitals master items');
//       } else {
//         setState(() {
//           _errorMessage = response['message'] ?? 'Failed to load vitals data';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Error loading vitals data: $e';
//       });
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   String _getVitalHint(String vitalId) {
//     if (_vitalsMasterData.isEmpty) {
//       return '(0-0)';
//     }
    
//     try {
//       for (var vital in _vitalsMasterData) {
//         final id = vital['id']?.toString() ?? '';
//         if (id == vitalId) {
//           final min = vital['min_value_f']?.toString() ?? '0';
//           final max = vital['max_value_f']?.toString() ?? '0';
//           return '($min-$max)';
//         }
//       }
//     } catch (e) {
//       debugPrint('Error getting vital hint: $e');
//     }
    
//     return '(0-0)';
//   }

//   Future<void> _onSaveVitals() async {
//     setState(() {
//       _errorMessage = null;
//     });

//     debugPrint('=== PATIENT INFO FOR VITALS ===');
//     debugPrint('Patient Name: ${widget.patient.patientname}');
//     debugPrint('IPD No: ${widget.patient.ipdNo}');
//     debugPrint('Patient ID (from patientId field): ${widget.patient.patientId}');
//     debugPrint('Patient ID (from id field): ${widget.patient.id}');
//     debugPrint('Admission ID: ${widget.patient.admissionId}');
//     debugPrint('All patient fields available:');
//     debugPrint('- patientId: ${widget.patient.patientId}');
//     debugPrint('- id: ${widget.patient.id}');
//     debugPrint('- admissionId: ${widget.patient.admissionId}');
//     debugPrint('- ipdNo: ${widget.patient.ipdNo}');
//     debugPrint('===============================');

//     if (_dateController.text.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please select a date';
//       });
//       return;
//     }

//     String admissionId = widget.patient.admissionId?.toString() ?? '';
    
//     if (admissionId.isEmpty || admissionId == '0') {
//       final prefs = await SharedPreferences.getInstance();
//       admissionId = prefs.getString('admissionid') ?? '';
//     }
    
//     if (admissionId.isEmpty || admissionId == '0') {
//       setState(() {
//         _errorMessage = 'Valid Admission ID not found. Please refresh patient data.';
//       });
//       debugPrint('ERROR: Invalid admission ID: $admissionId');
//       return;
//     }

//     String patientId = widget.patient.patientId?.toString() ?? '';
    
//     if (patientId.isEmpty) {
//       patientId = widget.patient.id?.toString() ?? '';
//     }
    
//     if (patientId.isEmpty) {
//       setState(() {
//         _errorMessage = 'Patient ID not found in patient data.';
//       });
//       debugPrint('ERROR: Could not find patient ID in patient object');
//       return;
//     }

//     debugPrint('=== VITALS SAVE REQUEST ===');
//     debugPrint('Patient ID: $patientId');
//     debugPrint('Admission ID: $admissionId');
//     debugPrint('Date: ${_dateController.text}');
//     debugPrint('Time: $_selectedHH:$_selectedMM');
//     debugPrint('============================');

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final vitalEntries = _prepareVitalEntries();

//       if (vitalEntries.isEmpty) {
//         setState(() {
//           _errorMessage = 'Please enter at least one vital sign';
//           _isLoading = false;
//         });
//         return;
//       }

//       debugPrint('Sending ${vitalEntries.length} vital entries');

//       final response = await _ipdService.savePatientVitals(
//         patientId: patientId,
//         admissionId: admissionId,
//         date: _dateController.text, 
//         time: '$_selectedHH:$_selectedMM',
//         vitalEntries: vitalEntries,
//       );

//       debugPrint('Save vitals response received');
//       debugPrint('Success: ${response['success']}');
//       debugPrint('Message: ${response['message']}');
//       debugPrint('Error: ${response['error']}');

//       if (response['success'] == true) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(response['message'] ?? 'Vitals saved successfully'),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 2),
//             ),
//           );
          
//           Navigator.pop(context);
//         }
//       } else {
//         setState(() {
//           _errorMessage = response['message'] ?? 'Failed to save vitals.';
//           if (response['error'] != null) {
//             _errorMessage = '${_errorMessage}\nAPI Error: ${response['error']}';
//           }
//         });
//       }
//     } catch (e, stackTrace) {
//       debugPrint('Error saving vitals: $e');
//       debugPrint('StackTrace: $stackTrace');
//       setState(() {
//         _errorMessage = 'Network error: ${e.toString()}';
//       });
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   List<Map<String, dynamic>> _prepareVitalEntries() {
//     final entries = <Map<String, dynamic>>[];
    
//     if (_tempController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 1, 'finding': _tempController.text});
//     }
//     if (_hrController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 2, 'finding': _hrController.text});
//     }
//     if (_rrController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 3, 'finding': _rrController.text});
//     }
//     if (_sysBpController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 4, 'finding': _sysBpController.text});
//     }
//     if (_diaBpController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 5, 'finding': _diaBpController.text});
//     }
//     if (_rbsController.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 6, 'finding': _rbsController.text});
//     }
//     if (_spo2Controller.text.isNotEmpty) {
//       entries.add({'vitalMasterId': 13, 'finding': _spo2Controller.text});
//     }
    
//     debugPrint('Prepared ${entries.length} vital entries');
//     return entries;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.90,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       child: Stack(
//         children: [
//           Column(
//             children: [
//               Container(
//                 padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
//                 decoration: BoxDecoration(
//                   border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text("Capture Vitals", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: darkBlue)),
//                           Text("${widget.patient.patientname} | IPD: ${widget.patient.ipdNo}", 
//                             style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
//                             maxLines: 1, overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                     GestureDetector(
//                       onTap: _isLoading ? null : () => Navigator.pop(context),
//                       child: Container(
//                         padding: const EdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: _isLoading ? Colors.grey[200] : Colors.grey[100],
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Icon(
//                           Icons.close,
//                           color: _isLoading ? Colors.grey[400] : Colors.black54,
//                           size: 20,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
              
//               if (_errorMessage != null)
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                   color: Colors.red[50],
//                   child: Row(
//                     children: [
//                       const Icon(Icons.error_outline, color: Colors.red, size: 16),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           _errorMessage!,
//                           style: const TextStyle(color: Colors.red, fontSize: 12),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildSectionHeader("Date & Time"),
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(color: Colors.grey[200]!),
//                           boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
//                         ),
//                         child: Column(
//                           children: [
//                             GestureDetector(
//                               onTap: _isLoading ? null : () async {
//                                 DateTime? picked = await showDatePicker(
//                                   context: context, 
//                                   initialDate: DateTime.now(), 
//                                   firstDate: DateTime(2020), 
//                                   lastDate: DateTime(2030),
//                                   builder: (context, child) {
//                                     return Theme(
//                                       data: ThemeData.light().copyWith(
//                                         colorScheme: const ColorScheme.light(primary: darkBlue),
//                                       ),
//                                       child: child!,
//                                     );
//                                   }
//                                 );
//                                 if (picked != null && mounted) {
//                                   setState(() {
//                                     _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
//                                   });
//                                 }
//                               },
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
//                                 decoration: BoxDecoration(
//                                   color: bgGrey,
//                                   borderRadius: BorderRadius.circular(12),
//                                   border: Border.all(color: Colors.grey[200]!),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     const Icon(Icons.calendar_month, color: darkBlue, size: 20),
//                                     const SizedBox(width: 10),
//                                     Text(_dateController.text, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
//                                     const Spacer(),
//                                     Icon(Icons.edit, color: Colors.grey[400], size: 16),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 12),
                            
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: _buildTimeDropdown(
//                                     label: "Hour",
//                                     value: _selectedHH,
//                                     items: _hours,
//                                     onChanged: (value) {
//                                       if (!_isLoading && value != null) {
//                                         setState(() => _selectedHH = value);
//                                       }
//                                     },
//                                   ),
//                                 ),
//                                 const SizedBox(width: 10),
//                                 const Text(":", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//                                 const SizedBox(width: 10),
//                                 Expanded(
//                                   child: _buildTimeDropdown(
//                                     label: "Minute",
//                                     value: _selectedMM,
//                                     items: _minutes,
//                                     onChanged: (value) {
//                                       if (!_isLoading && value != null) {
//                                         setState(() => _selectedMM = value);
//                                       }
//                                     },
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(height: 20),

//                       _buildSectionHeader("Vital Signs"),
                      
//                       Row(
//                         children: [
//                           Expanded(child: _buildModernInput(
//                             controller: _tempController, 
//                             label: "Temp F ${_getVitalHint('1')}", 
//                             hint: "98.6", 
//                             icon: Icons.thermostat, 
//                             suffix: "°F",
//                             keyboardType: TextInputType.number,
//                           )),
//                           const SizedBox(width: 15),
//                           Expanded(child: _buildModernInput(
//                             controller: _hrController, 
//                             label: "Heart Rate ${_getVitalHint('2')}", 
//                             hint: "72", 
//                             icon: Icons.monitor_heart, 
//                             suffix: "bpm",
//                             keyboardType: TextInputType.number,
//                           )),
//                         ],
//                       ),
//                       const SizedBox(height: 15),

//                       Row(
//                         children: [
//                           Expanded(child: _buildModernInput(
//                             controller: _sysBpController, 
//                             label: "Sys BP ${_getVitalHint('4')}", 
//                             hint: "120", 
//                             icon: Icons.arrow_upward, 
//                             suffix: "mmHg",
//                             keyboardType: TextInputType.number,
//                           )),
//                           const SizedBox(width: 15),
//                           Expanded(child: _buildModernInput(
//                             controller: _diaBpController, 
//                             label: "Dia BP ${_getVitalHint('5')}", 
//                             hint: "80", 
//                             icon: Icons.arrow_downward, 
//                             suffix: "mmHg",
//                             keyboardType: TextInputType.number,
//                           )),
//                         ],
//                       ),
//                       const SizedBox(height: 15),

//                       Row(
//                         children: [
//                           Expanded(child: _buildModernInput(
//                             controller: _rrController, 
//                             label: "Resp. Rate ${_getVitalHint('3')}", 
//                             hint: "18", 
//                             icon: Icons.air, 
//                             suffix: "/min",
//                             keyboardType: TextInputType.number,
//                           )),
//                           const SizedBox(width: 15),
//                           Expanded(child: _buildModernInput(
//                             controller: _spo2Controller, 
//                             label: "SpO2 ${_getVitalHint('13')}", 
//                             hint: "98", 
//                             icon: Icons.water_drop, 
//                             suffix: "%",
//                             keyboardType: TextInputType.number,
//                           )),
//                         ],
//                       ),
//                       const SizedBox(height: 15),

//                       _buildModernInput(
//                         controller: _rbsController, 
//                         label: "RBS ${_getVitalHint('6')}", 
//                         hint: "100", 
//                         icon: Icons.bloodtype, 
//                         suffix: "mg/dL",
//                         keyboardType: TextInputType.number,
//                       ),
                      
//                       const SizedBox(height: 40),
//                     ],
//                   ),
//                 ),
//               ),

//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
//                 ),
//                 child: SizedBox(
//                   width: double.infinity,
//                   height: 50,
//                   child: ElevatedButton(
//                     onPressed: _isLoading ? null : _onSaveVitals,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: darkBlue,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                       elevation: 5,
//                       shadowColor: darkBlue.withOpacity(0.3),
//                     ),
//                     child: _isLoading 
//                         ? const SizedBox(
//                             height: 20,
//                             width: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                             ),
//                           )
//                         : Text("Save Vitals", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           if (_isLoading)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black54,
//                 child: const Center(
//                   child: CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10, left: 2),
//       child: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
//     );
//   }

//   Widget _buildModernInput({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     String? hint,
//     String? suffix,
//     TextInputType keyboardType = TextInputType.number,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
//         const SizedBox(height: 6),
//         Container(
//           decoration: BoxDecoration(
//             color: bgGrey,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey[200]!),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: keyboardType,
//             enabled: !_isLoading,
//             style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
//             decoration: InputDecoration(
//               prefixIcon: Icon(icon, color: darkBlue.withOpacity(0.7), size: 18),
//               suffixText: suffix,
//               suffixStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
//               hintText: hint,
//               hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
//               border: InputBorder.none,
//               contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTimeDropdown({
//     required String label,
//     required String value,
//     required List<String> items,
//     required ValueChanged<String?> onChanged,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
//         const SizedBox(height: 6),
//         Container(
//           height: 48,
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           decoration: BoxDecoration(
//             color: bgGrey,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey[200]!),
//           ),
//           child: DropdownButtonHideUnderline(
//             child: DropdownButton<String>(
//               value: value,
//               isExpanded: true,
//               icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
//               style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
//               items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
//               onChanged: onChanged,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

class TreatmentRecordWebViewPage extends StatefulWidget {
  final Patient patient;
  const TreatmentRecordWebViewPage({super.key, required this.patient});

  @override
  State<TreatmentRecordWebViewPage> createState() => _TreatmentRecordWebViewPageState();
}

class _TreatmentRecordWebViewPageState extends State<TreatmentRecordWebViewPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  String get _webViewUrl {
    const baseUrl = "https://test.smartcarehis.com:8443/sclyte/patientTreatmentRecords";
    
    final admissionId = widget.patient.admissionId?.toString() ?? '';
    final patientId = widget.patient.patientId?.toString() ?? widget.patient.id?.toString() ?? '';
    final ipdNo = widget.patient.ipdNo;
    
    final params = {
      'admissionId': admissionId,
      'patientId': patientId,
      'ipdNo': ipdNo,
      'patientName': widget.patient.patientname,
      'ward': widget.patient.ward,
      'bed': widget.patient.bedname,
    };
    
    final queryString = params.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    
    return queryString.isNotEmpty ? '$baseUrl?$queryString' : baseUrl;
  }

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_webViewUrl));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Loading WebView URL: $_webViewUrl');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Treatment Record - ${widget.patient.patientname}",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _webViewController,
          ),
          if (_isLoading && _progress < 1.0)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading Treatment Records...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patient: ${widget.patient.patientname}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
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
}