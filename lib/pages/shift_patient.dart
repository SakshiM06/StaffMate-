import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/patient.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift Patient',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const ShiftPatientPage(),
    );
  }
}

class ShiftPatientPage extends StatefulWidget {
  final Patient? patient; // Optional patient parameter

  const ShiftPatientPage({super.key, this.patient});

  @override
  State<ShiftPatientPage> createState() => _ShiftPatientPageState();
}

class _ShiftPatientPageState extends State<ShiftPatientPage> {
  final TextEditingController _patientNameController = TextEditingController();
  final IpdService _ipdService = IpdService();
  
  String? _selectedWard;
  String? _selectedWardId; // Store ward ID for API calls
  String? _selectedBed;
  String? _selectedBedId; // Store bed ID for submission
  TimeOfDay? _selectedTime;
  
  bool _isLoadingWards = false;
  bool _isLoadingBeds = false;
  bool _isSubmitting = false; // For loading state during API call
  
  List<dynamic> _wards = []; // Store wards from API
  List<String> _wardNames = []; // Store ward names as strings for display (without IDs)
  List<dynamic> _bedsData = []; // Store bed objects from API
  List<String> _bedNames = []; // Store bed names as strings for display
  String? _branchId; // Store branch ID from SharedPreferences
  Patient? _patient; // Store patient data
  String? _practitionerId; // Store practitioner ID from patient data or prefs
  String? _practitionerName; // Store practitioner name

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _loadBranchIdAndFetchWards();
    _loadPractitionerData();
    
    // If patient data is provided, pre-fill the patient name
    if (_patient != null) {
      _patientNameController.text = _patient!.patientname;
    }
  }

  Future<void> _loadPractitionerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _practitionerId = _patient?.practitionerid ?? prefs.getString('practitionerId') ?? '';
      _practitionerName = prefs.getString('practitionerName') ?? 'Dr. Unknown';
    });
    debugPrint('Loaded practitioner: $_practitionerName ($_practitionerId)');
  }

  Future<void> _loadBranchIdAndFetchWards() async {
    setState(() {
      _isLoadingWards = true;
    });

    try {
      // Get branch ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _branchId = prefs.getString('branchId') ?? '1'; // Default to '1' if not found
      
      debugPrint('Loading wards for branch ID: $_branchId');
      
      // Fetch wards from API
      final wards = await _ipdService.fetchBranchWardList(
        branchId: _branchId!,
      );
      
      debugPrint('Raw wards data: $wards');
      
      // Extract ward names for display (ONLY names, no IDs)
      final wardNames = wards.map((ward) {
        if (ward is Map<String, dynamic>) {
          // Check for wardname field (lowercase as in your API response)
          if (ward.containsKey('wardname')) {
            return ward['wardname']?.toString() ?? 'Unknown Ward';
          }
          // Check for wardName field (camelCase as fallback)
          else if (ward.containsKey('wardName')) {
            return ward['wardName']?.toString() ?? 'Unknown Ward';
          }
          // Check for name field as last resort
          else if (ward.containsKey('name')) {
            return ward['name']?.toString() ?? 'Unknown Ward';
          }
          else {
            debugPrint('Ward object missing expected fields: $ward');
            return 'Unknown Ward';
          }
        }
        debugPrint('Ward is not a Map: $ward');
        return ward.toString();
      }).toList();
      
      setState(() {
        _wards = wards;
        _wardNames = wardNames.cast<String>();
        _isLoadingWards = false;
      });
      
      debugPrint('Successfully loaded ${wards.length} wards');
      debugPrint('Ward names: $_wardNames'); // Verify only names are shown
    } catch (e, stackTrace) {
      debugPrint('Error loading wards: $e');
      debugPrint('StackTrace: $stackTrace');
      
      setState(() {
        _isLoadingWards = false;
      });
      
      _showSnackBar('Failed to load wards: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _fetchBedsForWard(String wardId) async {
    setState(() {
      _isLoadingBeds = true;
      _bedsData = [];
      _bedNames = [];
      _selectedBed = null;
      _selectedBedId = null;
    });

    try {
      debugPrint('Fetching beds for ward ID: $wardId');
      
      // Fetch beds from API
      final beds = await _ipdService.fetchAvailableBedsInWard(
        wardId: wardId,
      );
      
      debugPrint('Raw beds data: $beds');
      
      // Extract bed names for display
      final bedNames = beds.map((bed) {
        if (bed is Map<String, dynamic>) {
          // Check for bedname field (lowercase)
          if (bed.containsKey('bedname')) {
            return bed['bedname']?.toString() ?? 'Unknown Bed';
          }
          // Check for bedName field (camelCase)
          else if (bed.containsKey('bedName')) {
            return bed['bedName']?.toString() ?? 'Unknown Bed';
          }
          // Check for name field
          else if (bed.containsKey('name')) {
            return bed['name']?.toString() ?? 'Unknown Bed';
          }
          else {
            debugPrint('Bed object missing expected fields: $bed');
            return 'Unknown Bed';
          }
        }
        debugPrint('Bed is not a Map: $bed');
        return bed.toString();
      }).toList();
      
      setState(() {
        _bedsData = beds;
        _bedNames = bedNames.cast<String>();
        _isLoadingBeds = false;
      });
      
      debugPrint('Successfully loaded ${beds.length} beds for ward: $wardId');
      debugPrint('Bed names: $_bedNames');
      
      // Automatically show bed selection sheet after loading
      if (_bedNames.isNotEmpty) {
        _showBedSelectionSheet();
      } else {
        _showSnackBar('No beds available in this ward', Colors.orange);
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading beds: $e');
      debugPrint('StackTrace: $stackTrace');
      
      setState(() {
        _isLoadingBeds = false;
      });
      
      _showSnackBar('Failed to load beds: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF1A237E),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A237E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showWardSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MinimalSelectionSheet(
        title: 'Select Ward',
        items: _wardNames, // Now contains only ward names, no IDs
        isLoading: _isLoadingWards,
        onItemSelected: (wardName) {
          // Find the selected ward object by matching name
          final selectedWardObj = _wards.firstWhere(
            (ward) {
              if (ward is Map<String, dynamic>) {
                // Check for wardname field (lowercase)
                if (ward.containsKey('wardname')) {
                  return ward['wardname']?.toString() == wardName;
                }
                // Check for wardName field (camelCase)
                else if (ward.containsKey('wardName')) {
                  return ward['wardName']?.toString() == wardName;
                }
                // Check for name field
                else if (ward.containsKey('name')) {
                  return ward['name']?.toString() == wardName;
                }
              }
              return ward.toString() == wardName;
            },
            orElse: () => null,
          );
          
          if (selectedWardObj != null) {
            // Extract ward ID (stored internally, not shown to user)
            String wardId = '0';
            String wardDisplayName = wardName;
            
            if (selectedWardObj is Map<String, dynamic>) {
              // Try to get ID from various possible field names
              wardId = (selectedWardObj['wardId'] ?? 
                       selectedWardObj['id'] ?? 
                       selectedWardObj['wardid'] ?? 
                       '0').toString();
              // Use the display name (already just the name)
              wardDisplayName = wardName;
            }
            
            setState(() {
              _selectedWard = wardDisplayName; // Shows only name
              _selectedWardId = wardId; // Stores ID internally
              _selectedBed = null;
              _selectedBedId = null;
              _bedsData = [];
              _bedNames = [];
            });
            
            Navigator.pop(context);
            
            // Fetch beds for the selected ward
            _fetchBedsForWard(wardId);
          } else {
            Navigator.pop(context);
            _showSnackBar('Error selecting ward', Colors.red);
          }
        },
      ),
    );
  }

  void _showBedSelectionSheet() {
    if (_selectedWard == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MinimalSelectionSheet(
        title: 'Select Bed',
        items: _bedNames,
        isLoading: _isLoadingBeds,
        onItemSelected: (bedName) {
          // Find the selected bed object
          final selectedBedObj = _bedsData.firstWhere(
            (bed) {
              if (bed is Map<String, dynamic>) {
                // Check for bedname field (lowercase)
                if (bed.containsKey('bedname')) {
                  return bed['bedname']?.toString() == bedName;
                }
                // Check for bedName field (camelCase)
                else if (bed.containsKey('bedName')) {
                  return bed['bedName']?.toString() == bedName;
                }
                // Check for name field
                else if (bed.containsKey('name')) {
                  return bed['name']?.toString() == bedName;
                }
              }
              return bed.toString() == bedName;
            },
            orElse: () => null,
          );
          
          if (selectedBedObj != null) {
            // Extract bed ID
            String bedId = '0';
            String bedDisplayName = bedName;
            
            if (selectedBedObj is Map<String, dynamic>) {
              // Try to get ID from various possible field names
              bedId = (selectedBedObj['bedid'] ?? 
                      selectedBedObj['bedId'] ?? 
                      selectedBedObj['id'] ?? 
                      '0').toString();
              bedDisplayName = selectedBedObj['bedname']?.toString() ?? 
                              selectedBedObj['bedName']?.toString() ?? 
                              selectedBedObj['name']?.toString() ?? 
                              bedName;
            }
            
            setState(() {
              _selectedBed = bedDisplayName;
              _selectedBedId = bedId;
            });
          }
          
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _shiftPatientAndAddCharges() async {
    debugPrint('Shifting patient and adding charges...');
    
    // Format time for API submission (HH:mm:ss format)
    final formattedTime = DateFormat('HH:mm:ss').format(
      DateTime(2024, 1, 1, _selectedTime!.hour, _selectedTime!.minute)
    );
    
    try {
      // Step 1: Call the shift bed API
      final shiftResponse = await _ipdService.shiftPatientBed(
        patientId: _patient?.patientid ?? '',
        admissionId: _patient?.admissionId ?? '',
        wardId: _selectedWardId!,
        wardName: _selectedWard!,
        bedId: _selectedBedId!,
        bedName: _selectedBed!,
        shiftingTime: formattedTime,
        branchId: _branchId ?? '1',
        patientName: _patientNameController.text,
        smsOnBedChange: false,
        whatsappOnBedChange: false,
      );

      if (shiftResponse['success'] != true) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackBar('Failed to shift patient: ${shiftResponse['message']}', Colors.red);
        return;
      }

      debugPrint('Patient shifted successfully, now adding standard charges...');

      // Step 2: Call the add standard charges API
      final chargesResponse = await _ipdService.addStandardCharges(
        patientId: _patient?.patientid ?? '',
        admissionId: _patient?.admissionId ?? '',
        wardId: _selectedWardId!,
        branchId: _branchId ?? '1',
        patientName: _patientNameController.text,
        practitionerId: _practitionerId ?? '',
        practitionerName: _practitionerName ?? '',
        thirdpartyId: 0,
        appliedNewStandardCharges: false,
        whopay: "Client",
      );

      setState(() {
        _isSubmitting = false;
      });

      if (chargesResponse['success'] == true) {
        _showSnackBar('Patient shifted and charges added successfully', Colors.green);
        Navigator.pop(context); // Go back after success
      } else {
        _showSnackBar('Patient shifted but failed to add charges: ${chargesResponse['message']}', Colors.orange);
        // Still go back since patient was shifted
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('Error in shift and charges process: $e');
      debugPrint('StackTrace: $stackTrace');
      
      setState(() {
        _isSubmitting = false;
      });
      
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _submitForm() async {
    // Validation
    if (_patientNameController.text.isEmpty) {
      _showSnackBar('Please enter patient name', Colors.orange);
      return;
    }
    if (_selectedWard == null || _selectedWardId == null) {
      _showSnackBar('Please select a ward', Colors.orange);
      return;
    }
    if (_selectedBed == null || _selectedBedId == null) {
      _showSnackBar('Please select a bed', Colors.orange);
      return;
    }
    if (_selectedTime == null) {
      _showSnackBar('Please select shift time', Colors.orange);
      return;
    }

    // Prevent multiple submissions
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    // Show confirmation dialog for adding charges
    _showAddChargesDialog();
  }

  void _showAddChargesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Charges?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A237E),
            ),
          ),
          content: Text(
            'You must add charges for the new ward to shift the patient.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                setState(() {
                  _isSubmitting = false; // Reset submitting state
                });
                // Show alert message
                _showSnackBar('Please select Yes to add charges and shift patient', Colors.orange);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: Text(
                'No',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // User selected YES - shift patient AND add charges
                _shiftPatientAndAddCharges();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0289A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Yes',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1A237E);
    const Color accentBlue = Color(0xFF0289A1);
    const Color bgGrey = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          // Custom App Bar with Patient Name
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 15,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              color: darkBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Shift Patient",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_patientNameController.text.isNotEmpty)
                            Text(
                              _patientNameController.text,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Patient Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Information',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: darkBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: darkBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient Name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextField(
                                  controller: _patientNameController,
                                  readOnly: _patient != null,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter name',
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_patient != null && _patient!.ipdNo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 44),
                          child: Text(
                            "IPD: ${_patient!.ipdNo}",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Shift Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Details',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSelectionTile(
                        label: 'Ward',
                        value: _selectedWard, // Shows only name, no ID
                        icon: Icons.local_hospital_rounded,
                        placeholder: _isLoadingWards ? 'Loading wards...' : 'Select ward',
                        onTap: _isLoadingWards ? null : _showWardSelectionSheet,
                        isEnabled: !_isLoadingWards,
                      ),
                      const SizedBox(height: 12),
                      _buildSelectionTile(
                        label: 'Bed',
                        value: _selectedBed,
                        icon: Icons.bed_rounded,
                        placeholder: _selectedWard == null 
                            ? 'Select ward first' 
                            : (_isLoadingBeds ? 'Loading beds...' : (_bedNames.isEmpty ? 'No beds available' : 'Select bed')),
                        onTap: _selectedWard == null
                            ? () => _showSnackBar('Select ward first', Colors.orange)
                            : (_isLoadingBeds || _bedNames.isEmpty ? null : _showBedSelectionSheet),
                        isEnabled: _selectedWard != null && !_isLoadingBeds && _bedNames.isNotEmpty,
                      ),
                      const SizedBox(height: 12),
                      _buildSelectionTile(
                        label: 'Shift Time',
                        value: _selectedTime != null 
                            ? DateFormat('hh:mm a').format(
                                DateTime(2024, 1, 1, _selectedTime!.hour, _selectedTime!.minute)
                              )
                            : null,
                        icon: Icons.access_time_rounded,
                        placeholder: 'Select time',
                        onTap: _selectTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // Bottom Buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () {
                    setState(() {
                      _patientNameController.clear();
                      _selectedWard = null;
                      _selectedWardId = null;
                      _selectedBed = null;
                      _selectedBedId = null;
                      _selectedTime = null;
                      _bedsData = [];
                      _bedNames = [];
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: accentBlue.withOpacity(0.3),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Shift',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String? value,
    required IconData icon,
    required String placeholder,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    const accentBlue = Color(0xFF0289A1);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: isEnabled ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: value != null ? accentBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: value != null ? accentBlue : Colors.grey[400],
            size: 18,
          ),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value ?? placeholder,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
            color: value != null ? Colors.black87 : Colors.grey[400],
          ),
        ),
        trailing: isEnabled 
            ? Icon(
                Icons.keyboard_arrow_down_rounded,
                color: value != null ? accentBlue : Colors.grey[400],
                size: 20,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// Minimal Selection Sheet
class _MinimalSelectionSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool isLoading;
  final Function(String) onItemSelected;

  const _MinimalSelectionSheet({
    required this.title,
    required this.items,
    required this.isLoading,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A237E),
              ),
            ),
          ),
          const Divider(height: 1),
          // Items List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          'No items available',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: Icon(
                              title.contains('Ward') ? Icons.local_hospital_rounded : Icons.bed_rounded,
                              color: const Color(0xFF0289A1),
                              size: 18,
                            ),
                            title: Text(
                              items[index],
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            onTap: () => onItemSelected(items[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}