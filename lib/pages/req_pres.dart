import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/services/medicine_service.dart';
import 'package:staff_mate/services/save_service.dart';
import 'package:staff_mate/services/unit_service.dart';
import 'package:staff_mate/services/frequency_service.dart';
import 'package:staff_mate/services/add_service.dart';

class ReqPrescriptionPage extends StatefulWidget {
  final String patientName;
  final String? patientId;
  final String? practitionerId;

  const ReqPrescriptionPage({
    super.key,
    required this.patientName,
    this.patientId,
    this.practitionerId, 
    // required Patient patient,
  });

  @override
  State<ReqPrescriptionPage> createState() => _ReqPrescriptionPageState();
}

class _ReqPrescriptionPageState extends State<ReqPrescriptionPage> {
  final TextEditingController medicineController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController strengthController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();

  String? selectedUnit;
  int? selectedUnitId;
  String? selectedFrequency;
  String? selectedRoute;
  String? selectedInstruction;
  String? selectedDosageTime;

  List<String> units = [];
  bool unitsLoading = true;

  List<String> frequencies = [];
  List<String> routes = [];
  List<String> dosageTimes = [];
  bool frequencyDataLoading = true;

  final List<Map<String, dynamic>> _prescriptionItems = [];

  Map<String, dynamic> medicineDetails = {};

  // Dynamic patient and practitioner data
  String? _patientId;
  String? _practitionerId;
  String? _admissionId;
  String? _userId;
  String? _clientId;
  int? _locationId;
  int? _wardId;
  int? _bedId;

  @override
  void initState() {
    super.initState();
    _loadDynamicData();
    _loadUnits();
    _loadFrequencyData();

    // Add listeners for automatic quantity calculation
    durationController.addListener(_calculateQuantity);
  }

  /// Calculate quantity based on frequency and duration - Enhanced for up to 10 frequency parts
  void _calculateQuantity() {
    if (selectedFrequency != null && selectedFrequency!.isNotEmpty && durationController.text.isNotEmpty) {
      try {
        final duration = int.tryParse(durationController.text) ?? 0;
        if (duration > 0) {
          // Parse frequency (e.g., "1-0-1" or "1-1-1-1-1-1" or any pattern up to 10 parts)
          final parts = selectedFrequency!.split('-').where((p) => p.trim().isNotEmpty).toList();

          // Support up to 10 frequency parts
          if (parts.isNotEmpty && parts.length <= 10) {
            int dailyDose = 0;

            // Sum all parts of the frequency
            for (String part in parts) {
              // handle possible decimal or fractional parts by taking floor of parsed double
              final parsed = int.tryParse(part) ?? double.tryParse(part)?.toInt() ?? 0;
              dailyDose += parsed;
            }

            final totalQuantity = dailyDose * duration;

            if (mounted) {
              setState(() {
                qtyController.text = totalQuantity.toString();
              });
            }

            debugPrint('╔═══════════════════════════════════════════════════════╗');
            debugPrint('║          AUTO-CALCULATED QUANTITY                     ║');
            debugPrint('╠═══════════════════════════════════════════════════════╣');
            debugPrint('║ Frequency      : $selectedFrequency');
            debugPrint('║ Parts Count    : ${parts.length}');
            debugPrint('║ Daily Dose     : $dailyDose');
            debugPrint('║ Duration       : $duration days');
            debugPrint('║ Total Quantity : $totalQuantity');
            debugPrint('╚═══════════════════════════════════════════════════════╝');
          } else {
            // if too many parts, fallback to 1 * duration
            if (mounted) {
              setState(() {
                qtyController.text = duration.toString();
              });
            }
          }
        } else {
          // duration is zero or invalid
          if (mounted) {
            setState(() {
              qtyController.text = '';
            });
          }
        }
      } catch (e) {
        debugPrint('Error calculating quantity: $e');
      }
    } else {
      // Not enough data to calculate
      if (mounted) {
        setState(() {
          if (durationController.text.isEmpty) {
            qtyController.text = '';
          }
        });
      }
    }
  }

  /// Load dynamic data from SharedPreferences or widget parameters
  Future<void> _loadDynamicData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _practitionerId =
            widget.practitionerId ?? prefs.getString('practitionerId') ?? '';
        _patientId = widget.patientId ?? prefs.getString('patientId') ?? '';
        _admissionId = prefs.getString('admissionid') ?? '';
        _userId = prefs.getString('userId') ?? 'aureus';
        _clientId = prefs.getString('clientId') ?? '';
        _locationId = int.tryParse(prefs.getString('locationId') ?? '');
        _wardId = int.tryParse(prefs.getString('wardId') ?? '');
        _bedId = int.tryParse(prefs.getString('bedId') ?? '');
      });

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║          DYNAMIC DATA LOADED - PRESCRIPTION           ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ Patient Name      : ${widget.patientName}');
      debugPrint('║ Patient ID        : $_patientId');
      debugPrint('║ Practitioner ID   : $_practitionerId');
      debugPrint('║ Admission ID      : $_admissionId');
      debugPrint('║ User ID           : $_userId');
      debugPrint('║ Client ID         : $_clientId');
      debugPrint('║ Location ID       : $_locationId');
      debugPrint('║ Ward ID           : $_wardId');
      debugPrint('║ Bed ID            : $_bedId');
      debugPrint('╚═══════════════════════════════════════════════════════╝');
    } catch (e) {
      debugPrint('Error loading dynamic data: $e');
    }
  }

  Future<void> _loadUnits() async {
    try {
      final fetchedUnits = await UnitService.fetchUnits();
      await UnitService.cacheUnits(fetchedUnits);
      if (mounted) {
        setState(() {
          units = fetchedUnits.map((e) => e.toString()).toSet().toList();
          unitsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching units: $e");
      final cached = await UnitService.getCachedUnits();
      if (mounted) {
        setState(() {
          units = cached.map((e) => e.toString()).toSet().toList();
          unitsLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cached.isEmpty
                  ? "Failed to load units. No cached data found."
                  : "Failed to load units from API. Using cached.",
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadFrequencyData() async {
    try {
      final fetchedData = await FrequencyService.fetchFrequencies();
      if (mounted) {
        setState(() {
          frequencies = (fetchedData['frequencies'] ?? []).map((e) => e.toString()).toSet().toList();
          routes = (fetchedData['routes'] ?? []).map((e) => e.toString()).toSet().toList();
          dosageTimes = (fetchedData['dosageTimes'] ?? []).map((e) => e.toString()).toSet().toList();
          frequencyDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching frequency data: $e");
      final cached = await FrequencyService.getCachedData();
      if (mounted) {
        setState(() {
          frequencies = (cached['frequencies'] ?? []).map((e) => e.toString()).toSet().toList();
          routes = (cached['routes'] ?? []).map((e) => e.toString()).toSet().toList();
          dosageTimes = (cached['dosageTimes'] ?? []).map((e) => e.toString()).toSet().toList();
          frequencyDataLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (cached['frequencies']?.isEmpty ?? true)
                  ? "Failed to load frequency data. No cached data found."
                  : "Failed to load frequency data from API. Using cached.",
            ),
          ),
        );
      }
    }
  }

  Future<List<String>> _getMedicineSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      return await MedicineService.fetchMedicines(query: pattern);
    } catch (e) {
      debugPrint("Error fetching medicines: $e");
      return await MedicineService.getCachedMedicines();
    }
  }

  /// Enhanced auto-fill for all fields when medicine is selected
  Future<void> _fetchMedicineDetails(String medicineName) async {
    try {
      final details = await MedicineService.fetchMedicineDetails(medicineName);
      if (details != null) {
        medicineDetails = details;
        if (mounted) {
          setState(() {
            // Auto-fill Dosage
            if (details['weight'] != null && details['weight'].toString().isNotEmpty) {
              dosageController.text = details['weight']?.toString() ?? '';
            } else {
              dosageController.text = '';
            }

            // Auto-fill Strength
            if (details['strength'] != null && details['strength'].toString().isNotEmpty) {
              strengthController.text = details['strength']?.toString() ?? '';
            } else {
              strengthController.text = '';
            }

            // Auto-fill Dose
            if (details['dose'] != null && details['dose'].toString().isNotEmpty) {
              doseController.text = details['dose']?.toString() ?? '';
            } else {
              doseController.text = '';
            }

            // Auto-fill Unit
            if (details['unit'] != null && details['unit'].toString().isNotEmpty) {
              selectedUnit = details['unit']?.toString();
              selectedUnitId = details['unitid'] is int ? details['unitid'] : int.tryParse('${details['unitid']}');
            }

            // Auto-fill Frequency
            if (details['dosefreq'] != null && details['dosefreq'].toString().isNotEmpty) {
              selectedFrequency = details['dosefreq']?.toString();
            } else {
              selectedFrequency ??= '1-0-1';
            }

            // Auto-fill Route
            if (details['route'] != null && details['route'].toString().isNotEmpty) {
              selectedRoute = details['route']?.toString();
            } else {
              selectedRoute = selectedRoute ?? 'ORAL'; // Default if not provided
            }

            // Auto-fill Instruction/Dosage Time
            if (details['dosageTime'] != null && details['dosageTime'].toString().isNotEmpty) {
              selectedDosageTime = details['dosageTime']?.toString();
              selectedInstruction = details['dosageTime']?.toString();
            } else if (details['instruction'] != null && details['instruction'].toString().isNotEmpty) {
              selectedDosageTime = details['instruction']?.toString();
              selectedInstruction = details['instruction']?.toString();
            } else {
              // fallback: choose first available dosageTime if present
              if (dosageTimes.isNotEmpty) {
                selectedDosageTime = dosageTimes.first;
                selectedInstruction = dosageTimes.first;
              }
            }

            // Auto-fill Duration (Days)
            if (details['days'] != null && details['days'].toString().isNotEmpty) {
              durationController.text = details['days']?.toString() ?? '5';
            } else {
              durationController.text = durationController.text.isNotEmpty ? durationController.text : '5'; // keep existing if user set
            }

            // Auto-fill Quantity (will be calculated automatically but allow explicit quantity if provided)
            if (details['quantity'] != null && details['quantity'].toString().isNotEmpty) {
              qtyController.text = details['quantity']?.toString() ?? '';
            } else {
              // leave quantity to be computed by _calculateQuantity()
              qtyController.text = qtyController.text;
            }
          });

          // After setState finishes, calculate quantity using current frequency and duration
          Future.microtask(() => _calculateQuantity());

          debugPrint('╔═══════════════════════════════════════════════════════╗');
          debugPrint('║          MEDICINE AUTO-FILL COMPLETE                  ║');
          debugPrint('╠═══════════════════════════════════════════════════════╣');
          debugPrint('║ Medicine       : $medicineName');
          debugPrint('║ Dosage         : ${dosageController.text}');
          debugPrint('║ Unit           : ${selectedUnit ?? "Not set"}');
          debugPrint('║ Strength       : ${strengthController.text}');
          debugPrint('║ Frequency      : ${selectedFrequency ?? "Not set"}');
          debugPrint('║ Dose           : ${doseController.text}');
          debugPrint('║ Route          : ${selectedRoute ?? "Not set"}');
          debugPrint('║ Instruction    : ${selectedDosageTime ?? "Not set"}');
          debugPrint('║ Duration       : ${durationController.text} days');
          debugPrint('║ Quantity       : ${qtyController.text}');
          debugPrint('╚═══════════════════════════════════════════════════════╝');
        }
      }
    } catch (e) {
      debugPrint("Error fetching medicine details: $e");
    }
  }

  void _addPrescriptionItem() async {
    if (medicineController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a medicine")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      int safeParseInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

      double safeParseDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

      final medicineBody = {
        "caldose": 0,
        "catalogueid": safeParseInt(medicineDetails['catalogueid']),
        "days": int.tryParse(durationController.text) ?? 5,
        "dosage": safeParseDouble(dosageController.text),
        "dose": doseController.text.isNotEmpty ? doseController.text : "1",
        "dosefreq": selectedFrequency ?? "1-0-1",
        "frequencyid": safeParseInt(medicineDetails['frequencyid']),
        "genericname": medicineDetails['genericname'] ?? "",
        "id": safeParseInt(medicineDetails['id']),
        "iswbd": 0,
        "medicineUnit": selectedUnitId ?? 0,
        "medicine_name": medicineController.text,
        "qty": int.tryParse(qtyController.text) ?? 1,
        "remark": remarkController.text,
        "route": selectedRoute ?? "ORAL",
        "strength": safeParseDouble(strengthController.text),
      };

      final response = await AddMedicineService.postMedicineDetails(
        medicineBody,
      );

      if (mounted) Navigator.pop(context);

      setState(() {
        _prescriptionItems.add({
          'medicine': medicineController.text,
          'dosage': dosageController.text,
          'unit': selectedUnit,
          'strength': strengthController.text,
          'frequency': selectedFrequency,
          'dose': doseController.text,
          'route': selectedRoute,
          'instruction': selectedDosageTime,
          'dosageTime': selectedDosageTime,
          'duration': durationController.text,
          'quantity': qtyController.text,
          'remark': remarkController.text,
          'apiResponse': response,
          'medicineBody': medicineBody,
        });
      });

      debugPrint('\n╔════════════════════════════════════════════════════╗');
      debugPrint('║         MEDICINE ADDED TO PRESCRIPTION            ║');
      debugPrint('╠════════════════════════════════════════════════════╣');
      debugPrint('║ Medicine #${_prescriptionItems.length}');
      debugPrint('║ Name        : ${medicineController.text}');
      debugPrint(
        '║ Dosage      : ${dosageController.text} ${selectedUnit ?? ''}',
      );
      debugPrint('║ Strength    : ${strengthController.text}');
      debugPrint('║ Frequency   : ${selectedFrequency ?? 'Not set'}');
      debugPrint('║ Dose        : ${doseController.text}');
      debugPrint('║ Route       : ${selectedRoute ?? 'Not set'}');
      debugPrint('║ Duration    : ${durationController.text} days');
      debugPrint('║ Quantity    : ${qtyController.text}');
      debugPrint('║ Instruction : ${selectedDosageTime ?? 'None'}');
      debugPrint(
        '║ Remark      : ${remarkController.text.isEmpty ? 'None' : remarkController.text}',
      );
      debugPrint('╚════════════════════════════════════════════════════╝\n');

      _clearForm();
    } catch (e, st) {
      if (mounted) Navigator.pop(context);
      debugPrint("=== ERROR in _addPrescriptionItem === $e");
      debugPrint(st.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error adding medicine: $e")));
    }
  }

  void _clearForm() {
    medicineController.clear();
    dosageController.clear();
    strengthController.clear();
    doseController.clear();
    durationController.clear();
    qtyController.clear();
    remarkController.clear();
    setState(() {
      selectedUnit = null;
      selectedUnitId = null;
      selectedFrequency = null;
      selectedRoute = null;
      selectedInstruction = null;
      selectedDosageTime = null;
      medicineDetails = {};
    });
  }

  @override
  void dispose() {
    medicineController.dispose();
    dosageController.dispose();
    strengthController.dispose();
    doseController.dispose();
    durationController.dispose();
    qtyController.dispose();
    remarkController.dispose();
    super.dispose();
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
          "Prescription Request",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
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
            Text(
              "Patient: ${widget.patientName}${_patientId != null && _patientId!.isNotEmpty ? ' (ID: $_patientId)' : ''}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: screenWidth * 0.04,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),

            TypeAheadField<String>(
              suggestionsCallback: _getMedicineSuggestions,
              builder: (context, controller, focusNode) {
                controller.text = medicineController.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "Type Medicine Name",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      borderSide: const BorderSide(
                        color: Colors.indigo,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: screenWidth * 0.035,
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
                  onChanged: (val) => medicineController.text = val,
                );
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(
                    suggestion,
                    style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
                  ),
                );
              },
              onSelected: (suggestion) {
                setState(() => medicineController.text = suggestion);
                _fetchMedicineDetails(suggestion);
              },
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No items found!'),
              ),
            ),

            SizedBox(height: screenWidth * 0.03),

            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Dosage",
                    textController: dosageController,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Unit",
                    dropdownItems: unitsLoading
                        ? ["Loading..."]
                        : (units.isEmpty ? ["No units available"] : units),
                    selectedValue: selectedUnit,
                    onChanged: (val) {
                      setState(() {
                        selectedUnit = val;
                        // Attempt to set unitId from medicineDetails if names match
                        if (medicineDetails.isNotEmpty && medicineDetails['unit'] != null && val == medicineDetails['unit']) {
                          selectedUnitId = medicineDetails['unitid'] is int ? medicineDetails['unitid'] : int.tryParse('${medicineDetails['unitid']}');
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.03),
            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Strength",
                    textController: strengthController,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Frequency",
                    dropdownItems: frequencyDataLoading
                        ? ["Loading..."]
                        : (frequencies.isEmpty
                              ? ["No frequencies available"]
                              : frequencies),
                    selectedValue: selectedFrequency,
                    onChanged: (val) {
                      setState(() {
                        selectedFrequency = val;
                        // If no instruction selected, pick a sensible default (first dosageTime if available)
                        if ((selectedDosageTime == null || selectedDosageTime!.isEmpty) && dosageTimes.isNotEmpty) {
                          selectedDosageTime = dosageTimes.first;
                          selectedInstruction = dosageTimes.first;
                        }
                      });
                      // Recalculate quantity immediately when frequency changes
                      _calculateQuantity();
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.03),
            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "mg/kg/Dose",
                    textController: doseController,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Route",
                    dropdownItems: frequencyDataLoading
                        ? ["Loading..."]
                        : (routes.isEmpty ? ["No routes available"] : routes),
                    selectedValue: selectedRoute,
                    onChanged: (val) => setState(() => selectedRoute = val),
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.03),
            _buildInputSection(
              screenWidth,
              "Instruction",
              dropdownItems: frequencyDataLoading
                  ? ["Loading..."]
                  : (dosageTimes.isEmpty
                        ? ["No instructions available"]
                        : dosageTimes),
              selectedValue: selectedDosageTime,
              onChanged: (val) => setState(() {
                selectedDosageTime = val;
                selectedInstruction = val;
              }),
            ),

            SizedBox(height: screenWidth * 0.03),
            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Duration (Days)",
                    textController: durationController,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Quantity",
                    textController: qtyController,
                    readOnly: true,
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.03),
            Row(
              children: [
                Expanded(
                  child: _buildInputSection(
                    screenWidth,
                    "Remark",
                    textController: remarkController,
                    maxLines: 2,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                GestureDetector(
                  onTap: _addPrescriptionItem,
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: screenWidth * 0.06,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.03),
            if (_prescriptionItems.isNotEmpty)
              Container(
                constraints: BoxConstraints(
                  maxHeight: _prescriptionItems.length >= 3 ? 300 : 150,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildPrescriptionTable(screenWidth),
                  ),
                ),
              ),

            SizedBox(height: screenWidth * 0.06),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_prescriptionItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please add at least one medicine"),
                      ),
                    );
                    return;
                  }

                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final currentPatientId = prefs.getString('patientId') ?? _patientId ?? '';
                    final currentPractitionerId = prefs.getString('practitionerId') ?? _practitionerId ?? '';
                    final currentClientId = prefs.getString('clientId') ?? '';
                    final currentAdmissionId = prefs.getString('admissionid') ?? '';

                    debugPrint('╔═══════════════════════════════════════════════════════╗');
                    debugPrint('║     PRE-SUBMISSION ID VERIFICATION                    ║');
                    debugPrint('╠═══════════════════════════════════════════════════════╣');
                    debugPrint('║ Patient ID        : $currentPatientId');
                    debugPrint('║ Practitioner ID   : $currentPractitionerId');
                    debugPrint('║ Client ID         : $currentClientId');
                    debugPrint('║ Admission ID      : $currentAdmissionId');
                    debugPrint('╚═══════════════════════════════════════════════════════╝');

                    final savedRemarksList = await AddMedicineService.getRemarks();
                    final remarksString = savedRemarksList.isNotEmpty
                        ? savedRemarksList.join(', ')
                        : '';

                    final List<Map<String, dynamic>> prescriptionMedicines =
                        _prescriptionItems.map((item) {
                      final medicineBody = item['medicineBody'] as Map<String, dynamic>;
                      return {
                        "categoryid": 0,
                        "code": "",
                        "datetime": "",
                        "days": medicineBody['days']?.toString() ?? "5",
                        "deliver_statuss": 0,
                        "deliverd_datetime": "",
                        "deliverd_userid": "",
                        "dispriscsrno": "",
                        "dosage": medicineBody['dosage']?.toString() ?? "0.00",
                        "dose": medicineBody['dosefreq']?.toString() ?? "1-0-1",
                        "dr_qty": medicineBody['qty']?.toString() ?? "1",
                        "frequency": medicineBody['dosefreq']?.toString() ?? "1-0-1",
                        "frequency_id": medicineBody['frequencyid'] ?? 0,
                        "frequency_name": item['instruction'] ?? "Not specified",
                        "id": medicineBody['id'] ?? 0,
                        "instructions": item['instruction'] ?? "",
                        "intreatmentgiven": 0,
                        "ipdremovedt": "",
                        "ipdremoveuserid": "",
                        "ipdtimeshow": "",
                        "isipdremove": 0,
                        "isnurseprisc": 0,
                        "masterdose": "0",
                        "medicine_id": medicineBody['catalogueid'] ?? 0,
                        "medicinename": medicineBody['medicine_name'] ?? "",
                        "nurse_qty": medicineBody['qty']?.toString() ?? "",
                        "nurseuserid": "",
                        "parentid": 0,
                        "patientid": _clientId,
                        "practitionerid": currentPractitionerId,
                        "priscdurationtype": "",
                        "route": medicineBody['route'] ?? "ORAL",
                        "specializationid": 0,
                        "sqno": 0,
                        "total": "",
                        "type": "",
                        "strength": medicineBody['strength'] ?? 0,
                        "unitextension": item['unit'] ?? "",
                        "remark": medicineBody['remark'] ?? "",
                        "productMasterId": medicineBody['catalogueid'] ?? 0,
                      };
                    }).toList();

                    final prescriptionBody = {
                      "admission": "",
                      "admission_id": currentAdmissionId,
                      "billno": 0,
                      "remark": remarksString,
                      "department": 0,
                      "discharge": 0,
                      "dosenotes": "",
                      "dstatus": 0,
                      "english": 0,
                      "followupcount": 0,
                      "followupdate": "",
                      "followupstype": "",
                      "fromtreatmentgiven": 0,
                      "hindi": 0,
                      "lastmodified": "",
                      "location_s": 0,
                      "locationid": _locationId,
                      "opd_appointmentid": 0,
                      "patientid": _clientId,
                      "pending_datetime": "",
                      "pending_userid": "",
                      "postpay": 0,
                      "practitionerid": currentPractitionerId,
                      "prisc_status": 0,
                      "regional": 0,
                      "specializationid": 0,
                      "userid": _userId,
                      "tpId": 0,
                      "wardId": _wardId,
                      "bedId": _bedId,
                      "priscriptionmedicinelist": prescriptionMedicines,
                      "request_from": 0,
                      "surgeonList": [0],
                      "clientId": _clientId,
                    };

                    debugPrint('\n╔════════════════════════════════════════════════════════╗');
                    debugPrint('║       FINAL PRESCRIPTION SUBMISSION DETAILS            ║');
                    debugPrint('╠════════════════════════════════════════════════════════╣');
                    debugPrint('║ Patient         : ${widget.patientName}');
                    debugPrint('║ Patient ID      : $currentPatientId');
                    debugPrint('║ Practitioner ID : $currentPractitionerId');
                    debugPrint('║ Client ID       : $_clientId');
                    debugPrint('║ Admission ID    : $currentAdmissionId');
                    debugPrint('║ Location ID     : $_locationId');
                    debugPrint('║ Ward ID         : $_wardId');
                    debugPrint('║ Bed ID          : $_bedId');
                    debugPrint('║ User ID         : $_userId');
                    debugPrint('╠════════════════════════════════════════════════════════╣');
                    debugPrint('║ Total Medicines : ${_prescriptionItems.length}');
                    debugPrint('╠════════════════════════════════════════════════════════╣');

                    for (int i = 0; i < _prescriptionItems.length; i++) {
                      final item = _prescriptionItems[i];
                      debugPrint('║ Medicine ${i + 1}:');
                      debugPrint('║   - Name        : ${item['medicine']}');
                      debugPrint('║   - Dosage      : ${item['dosage']} ${item['unit']}');
                      debugPrint('║   - Strength    : ${item['strength']}');
                      debugPrint('║   - Frequency   : ${item['frequency']}');
                      debugPrint('║   - Duration    : ${item['duration']} days');
                      debugPrint('║   - Quantity    : ${item['quantity']}');
                      debugPrint('║   - Route       : ${item['route']}');
                      debugPrint('║   - Instruction : ${item['instruction'] ?? 'None'}');
                      debugPrint('║   - Remark      : ${item['remark'].isEmpty ? 'None' : item['remark']}');
                      if (i < _prescriptionItems.length - 1) {
                        debugPrint('╟────────────────────────────────────────────────────────╢');
                      }
                    }

                    debugPrint('╠════════════════════════════════════════════════════════╣');
                    debugPrint('║ Complete JSON Body:');
                    debugPrint(jsonEncode(prescriptionBody));
                    debugPrint('╚════════════════════════════════════════════════════════╝\n');

                    final response = await SavePrescriptionService.savePrescription(
                      prescriptionBody,
                    );

                    debugPrint('\n╔════════════════════════════════════════════════════════╗');
                    debugPrint('║                   API RESPONSE                         ║');
                    debugPrint('╠════════════════════════════════════════════════════════╣');
                    debugPrint('Response: $response');
                    debugPrint('╚════════════════════════════════════════════════════════╝\n');

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Prescription submitted successfully"),
                      ),
                    );

                    setState(() {
                      _prescriptionItems.clear();
                    });
                    await AddMedicineService.clearRemarks();
                    _clearForm();

                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error submitting prescription: $e"),
                      ),
                    );
                    debugPrint('Error: $e');
                  }
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(
                  "Submit Prescription",
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.04,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.025),
                  ),
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(
    double screenWidth,
    String hint, {
    TextEditingController? textController,
    List<String>? dropdownItems,
    String? selectedValue,
    ValueChanged<String?>? onChanged,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    // If a textController is provided, build a TextField
    if (textController != null) {
      return TextField(
        controller: textController,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: readOnly ? Colors.grey[50] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.02),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.02),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: screenWidth * 0.035,
          ),
        ),
        style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
        onChanged: (val) {
          // If user manually edits duration, recalc quantity
          if (textController == durationController) {
            _calculateQuantity();
          }
        },
      );
    }

    // Otherwise, build a Dropdown
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.02),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1), 
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: dropdownItems != null &&
                  (selectedValue != null && dropdownItems.contains(selectedValue))
              ? selectedValue
              : null,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(fontSize: screenWidth * 0.038),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
          items: dropdownItems
                  ?.toSet()
                  .toList()
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: GoogleFonts.poppins(
                          fontSize: screenWidth * 0.038,
                        ),
                      ),
                    ),
                  )
                  .toList() ??
              [],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPrescriptionTable(double screenWidth) {
    return DataTable(
      columnSpacing: screenWidth * 0.03,
      headingRowColor: MaterialStateProperty.all(Colors.indigo.withAlpha(25)),
      dataRowColor: MaterialStateProperty.all(Colors.white),
      border: TableBorder.all(color: Colors.grey.withAlpha(80), width: 1),
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Medicine')),
        DataColumn(label: Text('Dosage')),
        DataColumn(label: Text('Unit')),
        DataColumn(label: Text('Strength')),
        DataColumn(label: Text('Frequency')),
        DataColumn(label: Text('Dose')),
        DataColumn(label: Text('Route')),
        DataColumn(label: Text('Instruction')),
        DataColumn(label: Text('Duration')),
        DataColumn(label: Text('Quantity')),
        DataColumn(label: Text('Remark')),
        DataColumn(label: Text('Actions')),
      ],
      rows: _prescriptionItems.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> item = entry.value;
        return DataRow(
          cells: [
            DataCell(Text((index + 1).toString())),
            DataCell(Text(item['medicine'] ?? '')),
            DataCell(Text(item['dosage'] ?? '')),
            DataCell(Text(item['unit'] ?? '')),
            DataCell(Text(item['strength'] ?? '')),
            DataCell(Text(item['frequency'] ?? '')),
            DataCell(Text(item['dose'] ?? '')),
            DataCell(Text(item['route'] ?? '')),
            DataCell(Text(item['instruction'] ?? '')),
            DataCell(Text(item['duration'] ?? '')),
            DataCell(Text(item['quantity'] ?? '')),
            DataCell(Text(item['remark'] ?? '')),
            DataCell(
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: screenWidth * 0.04,
                  color: Colors.redAccent,
                ),
                onPressed: () {
                  setState(() {
                    _prescriptionItems.removeAt(index);
                  });

                  debugPrint('\n╔════════════════════════════════════════╗');
                  debugPrint('║      MEDICINE REMOVED                  ║');
                  debugPrint('╠════════════════════════════════════════╣');
                  debugPrint('║ Removed: ${item['medicine']}');
                  debugPrint('║ Remaining medicines: ${_prescriptionItems.length}');
                  debugPrint('╚════════════════════════════════════════╝\n');
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
