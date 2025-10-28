import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:staff_mate/models/patient.dart';
import '../services/investigation_service.dart';

class ReqInvestigationPage extends StatefulWidget {
  final String patientName;
  final Patient patient;
  const ReqInvestigationPage({super.key, required this.patient, required this.patientName});
  

  @override
  State<ReqInvestigationPage> createState() => _ReqInvestigationPageState();
}

class _ReqInvestigationPageState extends State<ReqInvestigationPage> {
  String? _selectedLocation;
  String? _selectedJobTitle;
  Map<String, dynamic>? _selectedInvestigationType; // Changed to store full object
  String? _selectedPackage;
  bool _isUrgent = false;

  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _parameterController = TextEditingController();
  final TextEditingController _indicationsController = TextEditingController();
  final TextEditingController _totalController =
      TextEditingController(text: "0");

  /// Consultant Name TypeAhead Controller
  final TextEditingController _consultantNameController =
      TextEditingController();

  /// Template TypeAhead Controller
  final TextEditingController _templateController = TextEditingController();

  final List<Map<String, dynamic>> _investigationItems = [];

  final List<String> locations = ["AH (Nagpur)", "Other Location"];
  List<String> jobTitles = [];

  List<Map<String, dynamic>> investigationTypes = []; // Store full objects
  List<dynamic> parameterList = []; // Store parameter list

  bool _isLoadingAmount = false;
  bool _isLoadingJobTitles = true;
  bool _isLoadingParameters = false;
  
  get selectedTpId => null;
  
  get selectedTestTypeId => null;
  
  get selectedWardId => null;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _loadInitialData();
  }

//   Future<void> _loadInitialData() async {
//     debugPrint('Loading initial data...: ${widget.patient.patientid}');
//     final patientData = await InvestigationService.fetchPatientInformation(patientId: widget.patient.patientid);


//     if (patientData != null) {
//       debugPrint('✅ Patient Info fetched successfully');
//       debugPrint('👤 ${jsonEncode(patientData)}');

//       // After fetching patient info, call GetCharge API
//       await _fetchChargeForInvestigation(patientData['investigationType'] ?? '');
//     } else {
//       debugPrint('⚠️ No patient info found for ${widget.patient.patientid}');
//     }

// setState(() {
//   _isLoading =false;
// });


//     debugPrint('Patient Data: $patientData');
//     setState(() {
//       _isLoadingJobTitles = true;
//     });

//     try {
//       // Fetch job titles dynamically
//       final jobTitleData = await InvestigationService.fetchJobTitleList();
      
//       debugPrint('Job Title Data: $jobTitleData');

//       if (jobTitleData.isEmpty) {
//         setState(() {
//           jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
//           _isLoadingJobTitles = false;
//         });
//         return;
//       }

//       setState(() {
//         try {
//           final allowedTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
//           final extractedTitles = jobTitleData
//               .map((e) {
//                 if (e is Map<String, dynamic>) {
//                   return (e['jobTitle'] ?? e['name'] ?? e['title'] ?? e['jobtitle'] ?? e['jobname'] ?? '').toString();
//                 } else if (e is String) {
//                   return e;
//                 } else {
//                   return '';
//                 }
//               })
//               .where((name) => name.isNotEmpty)
//               .toList();
          
//           debugPrint('Extracted Job Titles: $extractedTitles');
//           jobTitles = allowedTitles
//               .where((title) => extractedTitles.any((extracted) => 
//                   extracted.toLowerCase() == title.toLowerCase()))
//               .toList();
          
//           if (jobTitles.isEmpty) {
//             jobTitles = allowedTitles;
//           }
          
//           debugPrint('Filtered Job Titles (Only 4): $jobTitles');
//         } catch (e) {
//           debugPrint('Error extracting job titles: $e');
//           jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
//         }
        
//         _isLoadingJobTitles = false;
//       });
//     } catch (e) {
//       debugPrint('Error fetching job titles: $e');
//       setState(() {
//         jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
//         _isLoadingJobTitles = false;
//       });
//     }
//   }



Future<void> _loadInitialData() async {
  debugPrint('Loading initial data...: ${widget.patient.patientid}');

  final patientData = await InvestigationService.fetchPatientInformation(
    patientId: widget.patient.patientid,
  );

  if (patientData != null) {
    debugPrint('✅ Patient Info fetched successfully');
    debugPrint('Patient Data:  ${jsonEncode(patientData)}');

    // After fetching patient info, call GetCharge API
    await _fetchChargeForInvestigation(
        patientData['investigationType'] ?? '');
  } else {
    debugPrint('⚠️ No patient info found for ${widget.patient.patientid}');
  }

  setState(() {
    bool _isLoading = false;
    });

  debugPrint('Patient Data: $patientData');
  setState(() {
    _isLoadingJobTitles = true;
  });

  try {
    final jobTitleData = await InvestigationService.fetchJobTitleList();
    debugPrint('Job Title Data: $jobTitleData');

    if (jobTitleData.isEmpty) {
      setState(() {
        jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
        _isLoadingJobTitles = false;
      });
      return;
    }

    setState(() {
      final allowedTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
      final extractedTitles = jobTitleData
          .map((e) {
            if (e is Map<String, dynamic>) {
              return (e['jobTitle'] ??
                      e['name'] ??
                      e['title'] ??
                      e['jobtitle'] ??
                      e['jobname'] ??
                      '')
                  .toString();
            } else if (e is String) {
              return e;
            } else {
              return '';
            }
          })
          .where((name) => name.isNotEmpty)
          .toList();

      debugPrint('Extracted Job Titles: $extractedTitles');
      jobTitles = allowedTitles
          .where((title) => extractedTitles.any((extracted) =>
              extracted.toLowerCase() == title.toLowerCase()))
          .toList();

      if (jobTitles.isEmpty) {
        jobTitles = allowedTitles;
      }

      debugPrint('Filtered Job Titles (Only 4): $jobTitles');
      _isLoadingJobTitles = false;
    });
  } catch (e) {
    debugPrint('Error fetching job titles: $e');
    setState(() {
      jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
      _isLoadingJobTitles = false;
    });
  }
}

  @override
  void dispose() {
    _packageController.dispose();
    _dateController.dispose();
    _searchCodeController.dispose();
    _amountController.dispose();
    _parameterController.dispose();
    _indicationsController.dispose();
    _totalController.dispose();
    _consultantNameController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

// Future<void> _fetchChargeForInvestigation(String investigationType) async {
//   setState(() {
//     _isLoadingAmount = true;
//   });

//   try {
//     // String tpId = selectedTpId;             
//     // int testTypeId = selectedTestTypeId ?? 0;    
//     // String wardID = selectedWardId ?? '';         
//     // String testTypeName = investigationType;     
//         final String tpId = (selectedTpId ?? '').toString();
//     final int testTypeId = selectedTestTypeId ?? 0;
//     final String wardID = (selectedWardId ?? '').toString();
//     final String testTypeName = investigationType.isNotEmpty ? investigationType : '';

//     // ✅ Validate before calling API
//     if (tpId.isEmpty || wardID.isEmpty || testTypeId == 0 || testTypeName.isEmpty) {
//       debugPrint("⚠️ Missing required fields to fetch charge");
//         debugPrint("tpId=$tpId, wardID=$wardID, testTypeId=$testTypeId, testTypeName=$testTypeName");

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Please select TP, Ward, and Investigation type first.'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//       setState(() {
//         _isLoadingAmount = false;
//       });
//       return;
//     }

//     // ✅ Call API
//     final chargeResponse = await InvestigationService.getCharge(
//       tpId: tpId,
//       investigationId: testTypeId,
//       wardId: wardID,
//       name: testTypeName,
//     );

//     debugPrint('💰 Charge Response: $chargeResponse');

//     // ✅ Handle response
//     setState(() {
//       final amount = chargeResponse['charge'] ??
//           chargeResponse['amount'] ??
//           chargeResponse['data']?['charge'] ??
//           '0';
//       _amountController.text = amount.toString();
//       _isLoadingAmount = false;
//     });
//   } catch (e) {
//     debugPrint('❌ Error fetching charge: $e');
//     setState(() {
//       _isLoadingAmount = false;
//     });


Future<void> _fetchChargeForInvestigation(String investigationType) async {
  setState(() {
    _isLoadingAmount = true;
  });

  try {
    // ✅ Dynamically assign values (even if some are empty)
    final String tpId = selectedTpId?.toString() ?? '';
    final int testTypeId = selectedTestTypeId ?? 0;
    final String wardID = selectedWardId?.toString() ?? '';
    final String testTypeName = investigationType.isNotEmpty
        ? investigationType
        : (_selectedInvestigationType != null ? _selectedInvestigationType!['name'] ?? '' : '');

    // ✅ Log values instead of showing alert
    debugPrint('🔹 Fetching Charge with:');
    debugPrint('tpId=$tpId');
    debugPrint('wardID=$wardID');
    debugPrint('testTypeId=$testTypeId');
    debugPrint('testTypeName=$testTypeName');

    // ✅ Call API regardless (your backend will handle if anything is missing)
    final chargeResponse = await InvestigationService.getCharge(
      tpId: tpId,
      investigationId: testTypeId,
      wardId: wardID,
      name: testTypeName,
    );

    debugPrint('💰 Charge API Response: $chargeResponse');

    setState(() {
      final amount = chargeResponse['charge'] ??
          chargeResponse['amount'] ??
          chargeResponse['data']?['charge'] ??
          '0';
      _amountController.text = amount.toString();
      _isLoadingAmount = false;
    });
  } catch (e) {
    debugPrint('❌ Error fetching charge: $e');
    setState(() => _isLoadingAmount = false);
  }
}


  // Fetch parameters when investigation type is selected
  Future<void> _fetchParametersForInvestigationType() async {
    if (_selectedInvestigationType == null) return;

    setState(() {
      _isLoadingParameters = true;
    });

    try {
      final int typeId = _selectedInvestigationType!['id'] ?? 0;
      final String gender = widget.patient.gender;

      debugPrint('Fetching parameters for ID: $typeId, Gender: $gender');

      final params = await InvestigationService.fetchParameterList(
        investigationTypeId: typeId,
        gender: gender,
      );

      setState(() {
        parameterList = params;
        _isLoadingParameters = false;
      });

      debugPrint('Parameters fetched: ${parameterList.length} items');
    } catch (e) {
      debugPrint('Error fetching parameters: $e');
      setState(() {
        parameterList = [];
        _isLoadingParameters = false;
      });
    }
  }

  void _addItem() {
    if (_selectedInvestigationType != null &&
        _searchCodeController.text.isNotEmpty) {
      setState(() {
        _investigationItems.add({
          'package': _selectedPackage ?? '',
          'type': _selectedInvestigationType!['name'] ?? '',
          'typeId': _selectedInvestigationType!['id'] ?? 0,
          'gender': _selectedInvestigationType!['gender'] ?? '',
          'searchCode': _searchCodeController.text,
          'amount': _amountController.text,
          'parameter': _parameterController.text,
          'indications': _indicationsController.text,
          'urgent': _isUrgent,
        });
        _packageController.clear();
        _selectedPackage = null;
        _selectedInvestigationType = null;
        _searchCodeController.clear();
        _amountController.clear();
        _parameterController.clear();
        _indicationsController.clear();
        _isUrgent = false;
        parameterList = [];
        _updateTotal();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select an Investigation Type and enter a Search Code.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateTotal() {
    double total = 0;
    for (var item in _investigationItems) {
      total += double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    }
    _totalController.text = total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Investigation Request',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${widget.patient.patientname}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.04)),
            SizedBox(height: screenWidth * 0.05),
            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Location",
                    dropdownItems: locations,
                    selectedValue: _selectedLocation,
                    onChanged: (val) => setState(() => _selectedLocation = val),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(child: _buildDateSelectionField(screenWidth)),
              ],
            ),
            SizedBox(height: screenWidth * 0.03),
    
            _isLoadingJobTitles
                ? Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenWidth * 0.035),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Text('Loading Job Titles...',
                            style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.038)),
                      ],
                    ),
                  )
                : _buildInputSection(
                    screenWidth,
                    "Job Title",
                    dropdownItems: jobTitles,
                    selectedValue: _selectedJobTitle,
                    onChanged: (val) => setState(() => _selectedJobTitle = val),
                  ),
            
            SizedBox(height: screenWidth * 0.03),

            TypeAheadField<String>(
              suggestionsCallback: (pattern) async {
                final cached =
                    await InvestigationService.getCachedInvestigationTemplates();
                if (pattern.isEmpty && cached.isNotEmpty) return cached;
                final templates =
                    await InvestigationService.fetchInvestigationTemplates();
                return templates
                    .where((t) =>
                        t.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                _templateController.text = suggestion;
              },
              builder: (context, controller, focusNode) {
                controller.text = _templateController.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Investigation Template',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(screenWidth * 0.02),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenWidth * 0.035),
                  ),
                );
              },
            ),
            SizedBox(height: screenWidth * 0.03),
            Divider(height: screenWidth * 0.03, color: Colors.grey[400]),
            SizedBox(height: screenWidth * 0.03),
            Text('Investigation Items',
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                )),
            SizedBox(height: screenWidth * 0.02),
            _buildInvestigationInputRow(screenWidth),
            SizedBox(height: screenWidth * 0.02),
            if (_investigationItems.isNotEmpty)
              SizedBox(
                height: 300,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildInvestigationTable(screenWidth),
                    ),
                  ),
                ),
              ),
            SizedBox(height: screenWidth * 0.02),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total',
                      style: GoogleFonts.poppins(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  SizedBox(width: screenWidth * 0.02),
                  SizedBox(
                    width: screenWidth * 0.25,
                    child: _buildInputSection(
                      screenWidth,
                      "",
                      textController: _totalController,
                      readOnly: true,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenWidth * 0.03),

            /// Consultant Name TypeAhead
            TypeAheadField<String>(
              suggestionsCallback: (pattern) async {
                if (pattern.isEmpty) return [];
                final names = await InvestigationService.fetchPractitionersNames(
                  branchId: _selectedLocation == "AH (Nagpur)" ? "1" : "2",
                  specializationId: 0,
                  isVisitingConsultant: 0,
                );
                return names
                    .where((name) =>
                        name.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                setState(() {
                  _consultantNameController.text = suggestion;
                });
              },
              builder: (context, controller, focusNode) {
                controller.text = _consultantNameController.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Consultant Name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenWidth * 0.035),
                  ),
                );
              },
            ),

            SizedBox(height: screenWidth * 0.06),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Investigation Request Submitted!')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text('Submit Request',
                    style: GoogleFonts.poppins(
                        fontSize: screenWidth * 0.04, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(double screenWidth, String hint,
      {TextEditingController? textController,
      List<String>? dropdownItems,
      String? selectedValue,
      ValueChanged<String?>? onChanged,
      int maxLines = 1,
      bool readOnly = false}) {
    return textController != null
        ? TextField(
            controller: textController,
            maxLines: maxLines,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenWidth * 0.035),
            ),
            style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
          )
        : Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1))
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                hint: Text(hint,
                    style:
                        GoogleFonts.poppins(fontSize: screenWidth * 0.038)),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
                items: dropdownItems
                        ?.map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: GoogleFonts.poppins(
                                      fontSize: screenWidth * 0.038)),
                            ))
                        .toList() ??
                    [],
                onChanged: onChanged,
              ),
            ),
          );
  }

  Widget _buildDateSelectionField(double screenWidth) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: TextField(
          controller: _dateController,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Date / Time',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
                borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03, vertical: screenWidth * 0.035),
            suffixIcon: Icon(Icons.calendar_today,
                size: screenWidth * 0.05, color: Colors.indigo),
          ),
          style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
        ),
      ),
    );
  }

  Widget _buildInvestigationInputRow(double screenWidth) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TypeAheadField<String>(
                suggestionsCallback: (pattern) async {
                  if (pattern.isEmpty) {
                    return await InvestigationService.getCachedInvestigations();
                  }
                  return await InvestigationService.fetchInvestigations(
                      query: pattern);
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(title: Text(suggestion));
                },
                onSelected: (suggestion) {
                  setState(() {
                    _packageController.text = suggestion;
                    _selectedPackage = suggestion;
                  });
                },
                builder: (context, controller, focusNode) {
                  controller.text = _packageController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search Package',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(screenWidth * 0.02),
                          borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenWidth * 0.035),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: investigationTypes.isEmpty
                    ? InvestigationService.fetchInvestigationTypes(typeId: 5)
                    : Future.value(investigationTypes),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenWidth * 0.035),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Text('Loading...',
                              style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.038)),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text("Error loading types");
                  }
                  if (investigationTypes.isEmpty && snapshot.hasData) {
                    investigationTypes = snapshot.data!;
                  }
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedInvestigationType,
                        hint: Text('Investigation Type',
                            style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.038)),
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
                        items: investigationTypes
                            .map((type) => DropdownMenuItem<Map<String, dynamic>>(
                                  value: type,
                                  child: Text(type['name'] ?? '',
                                      style: GoogleFonts.poppins(
                                          fontSize: screenWidth * 0.038)),
                                ))
                            .toList(),
                        onChanged: (newValue) async {
                          setState(() => _selectedInvestigationType = newValue);
                          // Fetch charge and parameters when investigation type is selected
                          if (newValue != null) {
                            await _fetchChargeForInvestigation(newValue['name']);
                            await _fetchParametersForInvestigationType();
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        Row(
          children: [
            Expanded(
              child: _buildInputSection(screenWidth, 'Search Code',
                  textController: _searchCodeController),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Stack(
                children: [
                  _buildInputSection(screenWidth, 'Amount',
                      textController: _amountController),
                  if (_isLoadingAmount)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: .7),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildInputSection(screenWidth, 'Parameter',
                      textController: _parameterController),
                  if (_isLoadingParameters)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: .7),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: _buildInputSection(screenWidth, 'Indications',
                  textController: _indicationsController),
            ),
          ],
        ),
        // if (parameterList.isNotEmpty)
        //   Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       SizedBox(height: screenWidth * 0.02),
        //       Text('Available Parameters:',
        //           style: GoogleFonts.poppins(
        //               fontSize: screenWidth * 0.035,
        //               fontWeight: FontWeight.w500,
        //               color: Colors.grey[700])),
        //       SizedBox(height: screenWidth * 0.01),
        //       Wrap(
        //         spacing: 8,
        //         runSpacing: 8,
        //         children: parameterList.map((param) {
        //           final paramName = param['parameterName'] ?? 
        //                            param['name'] ?? 
        //                            param['parameter'] ?? 
        //                            'Unknown';
        //           return Chip(
        //             label: Text(paramName,
        //                 style: GoogleFonts.poppins(fontSize: screenWidth * 0.03)),
        //             backgroundColor: Colors.blue[50],
        //             onDeleted: null,
        //           );
        //         }).toList(),
        //       ),
        //     ],
        //   ),
        SizedBox(height: screenWidth * 0.03),
        Row(
          children: [
            // Urgent Checkbox
            Row(
              children: [
                Checkbox(
                  value: _isUrgent,
                  onChanged: (value) {
                    setState(() {
                      _isUrgent = value ?? false;
                    });
                  },
                  activeColor: Colors.blue,
                  checkColor: Colors.white,
                ),
                Text(
                  'Urgent',
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.038,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _addItem,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(screenWidth * 0.02)),
                child: Icon(Icons.add,
                    color: Colors.white, size: screenWidth * 0.06),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvestigationTable(double screenWidth) {
    return DataTable(
      columnSpacing: screenWidth * 0.03,
      headingRowColor: WidgetStateProperty.all(Colors.indigo.withAlpha(25)),
      dataRowColor: WidgetStateProperty.all(Colors.white),
      border: TableBorder.all(color: Colors.grey.withAlpha(80), width: 1),
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Package')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Search Code')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Parameter')),
        DataColumn(label: Text('Indications')),
        DataColumn(label: Text('Urgent')),
        DataColumn(label: Text('Actions')),
      ],
      rows: _investigationItems.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> item = entry.value;
        return DataRow(cells: [
          DataCell(Text((index + 1).toString())),
          DataCell(Text(item['package'] ?? '')),
          DataCell(Text(item['type'] ?? '')),
          DataCell(Text(item['searchCode'] ?? '')),
          DataCell(Text(item['amount']?.toString() ?? '0')),
          DataCell(Text(item['parameter'] ?? '')),
          DataCell(Text(item['indications'] ?? '')),
          DataCell(
            Icon(
              item['urgent'] == true ? Icons.check_circle : Icons.cancel,
              color: item['urgent'] == true ? Colors.blue : Colors.grey,
              size: screenWidth * 0.05,
            ),
          ),
          DataCell(IconButton(
            icon: Icon(Icons.delete,
                size: screenWidth * 0.04, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                _investigationItems.removeAt(index);
                _updateTotal();
              });
            },
          )),
        ]);
      }).toList(),
    );
  }
}