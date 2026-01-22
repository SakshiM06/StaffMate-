import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/patient.dart';

class ReqConsultantPage extends StatefulWidget {
  final String patientName;
  final String? ipdNo;
  final String? admissionId;
  final String? patientId;

  const ReqConsultantPage({
    super.key,
    required this.patientName,
    this.ipdNo,
    this.admissionId,
    this.patientId, required Patient patient,
  });

  @override
  State<ReqConsultantPage> createState() => _ReqConsultantPageState();
}

class _ReqConsultantPageState extends State<ReqConsultantPage> {
  final IpdService _ipdService = IpdService();
  
  // Form controllers
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _patientSearchController = TextEditingController();
  
  // State variables
  List<dynamic> _doctorList = [];
  List<dynamic> _specializationList = [];
  String? _selectedDoctor;
  String? _selectedSpecialization;
  bool _isLoading = false;
  bool _isDoctorLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // For patient search
  List<dynamic> _patientList = [];
  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedIpdNo;

  static const Color darkBlue = Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    // Set default dates (today)
    final now = DateTime.now();
    _fromDateController.text = DateFormat('dd/MM/yyyy').format(now);
    _toDateController.text = DateFormat('dd/MM/yyyy').format(now);
    
    // Set patient name if provided
    if (widget.patientName.isNotEmpty) {
      _patientSearchController.text = widget.patientName;
      _selectedPatientName = widget.patientName;
    }
    
    if (widget.ipdNo != null) {
      _selectedIpdNo = widget.ipdNo;
    }
    
    // Load initial data
    _loadSpecializationList();
    
    // If we have patient info, load doctors
    if (widget.patientName.isNotEmpty || widget.ipdNo != null) {
      _loadDoctors();
    }
    
    // Initialize patient search controller listener
    _patientSearchController.addListener(() {
      if (_patientSearchController.text.length > 2) {
        _searchPatients(_patientSearchController.text);
      }
    });
  }

  Future<void> _loadSpecializationList() async {
    try {
      final specializations = await _ipdService.fetchSpecializationList(branchId: "1");
      setState(() {
        _specializationList = specializations;
      });
    } catch (e) {
      debugPrint('Error loading specialization list: $e');
      setState(() {
        _errorMessage = 'Failed to load specializations';
      });
    }
  }

  Future<void> _loadDoctors({String? specializationId}) async {
    setState(() {
      _isDoctorLoading = true;
      _doctorList = [];
      _selectedDoctor = null;
    });

    try {
      final doctors = await _ipdService.fetchPractitionerList(
        branchId: "1",
        specializationId: specializationId != null ? int.parse(specializationId) : 0,
        isVisitingConsultant: 1,
      );
      
      setState(() {
        _doctorList = doctors;
        _isDoctorLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading doctor list: $e');
      setState(() {
        _errorMessage = 'Failed to load doctors';
        _isDoctorLoading = false;
      });
    }
  }

  Future<void> _searchPatients(String query) async {
    try {
      // In a real app, you would call an API to search for patients
      // For now, we'll simulate with a delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      // This is a mock implementation - replace with actual API call
      setState(() {
        _patientList = [
          {
            'id': '1',
            'name': 'John Doe',
            'ipdNo': 'IPD-001',
            'uhid': 'UHD-001'
          },
          {
            'id': '2',
            'name': 'Jane Smith',
            'ipdNo': 'IPD-002',
            'uhid': 'UHD-002'
          },
          {
            'id': '3',
            'name': widget.patientName.isNotEmpty ? widget.patientName : 'Robert Johnson',
            'ipdNo': widget.ipdNo ?? 'IPD-003',
            'uhid': 'UHD-003'
          }
        ].where((patient) => 
          patient['name']!.toLowerCase().contains(query.toLowerCase()) ||
          patient['ipdNo']!.toLowerCase().contains(query.toLowerCase()) ||
          patient['uhid']!.toLowerCase().contains(query.toLowerCase())
        ).toList();
      });
    } catch (e) {
      debugPrint('Error searching patients: $e');
    }
  }

  Future<void> _submitRequest() async {
    // Validation
    if (_selectedPatientName == null || _selectedPatientName!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a patient';
      });
      return;
    }
    
    if (_selectedDoctor == null) {
      setState(() {
        _errorMessage = 'Please select a doctor';
      });
      return;
    }
    
    if (_fromDateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please select From Date';
      });
      return;
    }
    
    if (_toDateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please select To Date';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Prepare request data
      final requestData = {
        'patientId': _selectedPatientId ?? widget.patientId ?? '',
        'patientName': _selectedPatientName,
        'ipdNo': _selectedIpdNo ?? widget.ipdNo ?? '',
        'admissionId': widget.admissionId ?? '',
        'doctorId': _selectedDoctor,
        'fromDate': _fromDateController.text,
        'toDate': _toDateController.text,
        'specializationId': _selectedSpecialization,
      };
      
      debugPrint('Submitting consultant request: $requestData');
      
      // In a real app, you would call an API like:
      // final response = await _ipdService.requestConsultant(requestData);
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isLoading = false;
        _successMessage = 'Consultant request submitted successfully!';
      });
      
      // Clear form after successful submission
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to submit request: $e';
      });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: darkBlue),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Request Consultant",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                "Consultant Request",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Request a visiting consultant for patient",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 25),

              // Error/Success Messages
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_successMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Search Patient Field
              _buildSectionHeader("Search Patient"),
              Container(
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _patientSearchController,
                  decoration: InputDecoration(
                    hintText: "Enter UHD / patient name",
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF1A237E)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                  ),
                ),
              ),

              // Show patient suggestions if available
              if (_patientList.isNotEmpty && _patientSearchController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _patientList.map((patient) {
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xFF1A237E),
                          child: Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                        title: Text(
                          patient['name'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "IPD: ${patient['ipdNo']} | UHD: ${patient['uhid']}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPatientName = patient['name'];
                            _selectedPatientId = patient['id'];
                            _selectedIpdNo = patient['ipdNo'];
                            _patientSearchController.text = patient['name'];
                            _patientList = []; // Clear suggestions
                          });
                          FocusScope.of(context).unfocus();
                        },
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // Date Fields
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("From Date"),
                        GestureDetector(
                          onTap: () => _selectDate(context, _fromDateController),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: bgGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFF1A237E), size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _fromDateController.text,
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("To Date"),
                        GestureDetector(
                          onTap: () => _selectDate(context, _toDateController),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: bgGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFF1A237E), size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _toDateController.text,
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Specialization Dropdown
              _buildSectionHeader("Select Specialization"),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSpecialization,
                    isExpanded: true,
                    hint: Text(
                      "Select Specialization",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("All Specializations"),
                      ),
                      ..._specializationList.map((specialization) {
                        final id = specialization['id']?.toString() ?? '';
                        final name = specialization['specialization_name']?.toString() ?? 'Unknown';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSpecialization = value;
                        _selectedDoctor = null;
                      });
                      _loadDoctors(specializationId: value);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Doctor Dropdown
              _buildSectionHeader("Select Doctor"),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _isDoctorLoading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDoctor,
                          isExpanded: true,
                          hint: Text(
                            "Select Doctor",
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text("Select a doctor"),
                            ),
                            ..._doctorList.map((doctor) {
                              final id = doctor['id']?.toString() ?? '';
                              final name = doctor['fullname']?.toString() ?? doctor['name']?.toString() ?? 'Unknown';
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDoctor = value;
                            });
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 30),

              // Info Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Important Information",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "• Medicines included as charges in the patient's account will not be available for nurse return.",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "• 3rd and 4th steps are set at 4th and 5th steps are set at 5th and 6th steps are set at 7th.",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: darkBlue.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Submit Request",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }
}