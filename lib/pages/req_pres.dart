import 'dart:async';
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
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ReqPrescriptionPage extends StatefulWidget {
  final Patient patient; 
  final String? patientId;
  final String? practitionerId;

  const ReqPrescriptionPage({
    super.key,
    required this.patient,
    this.patientId,
    this.practitionerId, required String patientName,
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

  String? _patientId;
  String? _practitionerId;
  String? _admissionId;
  String? _userId;
  String? _clientId;
  int? _locationId;
  int? _wardId;
  int? _bedId;
  late Patient _patient;
  final _typeAheadController = TextEditingController();
  final FocusNode _typeAheadFocusNode = FocusNode();
  final FocusNode _dosageFocusNode = FocusNode();
  final FocusNode _strengthFocusNode = FocusNode();
  final FocusNode _durationFocusNode = FocusNode();
  final FocusNode _remarkFocusNode = FocusNode();

  bool _showTypeAheadDropdown = true;

  static const int _maxMedicineLimit = 15;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  Timer? _speechTimeoutTimer;


  bool _voiceCommandApplied = false;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    
    _initSpeech();
    _loadDynamicData();
    _loadUnits();
    _loadFrequencyData();
    durationController.addListener(_calculateQuantity);
 
    _logPatientData();
  }
  
  void _logPatientData() {
    // debugPrint('=== PATIENT DATA IN REQ PRESCRIPTION ===');
    // debugPrint('Patient Name: ${_patient.patientname}');
    // debugPrint('Patient ID (patientid): ${_patient.patientid}');
    // debugPrint('Patient ID (id): ${_patient.id}');
    // debugPrint('Admission ID: ${_patient.admissionId}');
    // debugPrint('IPD No: ${_patient.ipdNo}');
    // debugPrint('Client ID: ${_patient.clientId}');
    // debugPrint('Bed ID: ${_patient.bedid}');
    // debugPrint('Ward: ${_patient.ward}');
    // debugPrint('========================================');
  }

  @override
  void dispose() {
    _speechTimeoutTimer?.cancel();
    _typeAheadController.dispose();
    _typeAheadFocusNode.dispose();
    _dosageFocusNode.dispose();
    _strengthFocusNode.dispose();
    _durationFocusNode.dispose();
    _remarkFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            _stopListening();
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          _stopListening();
        },
      );
      
      if (!_speechAvailable) {
        debugPrint('Speech recognition not available on this device');
      }
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      _speechAvailable = false;
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device'),
            backgroundColor: Colors.orange,
             duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
        ),
        );
        return;
      }

      bool hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        bool permissionGranted = await _speech.initialize();
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for voice input'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
            ),
          ),
          );
          return;
        }
      }

      setState(() {
        _isListening = true;
        _recognizedText = '';
        _voiceCommandApplied = false;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });

          _speechTimeoutTimer?.cancel();
          _speechTimeoutTimer = Timer(const Duration(seconds: 60), () {
            if (_isListening) {
              _processVoiceCommand(_recognizedText);
            }
          });

          
          if (_recognizedText.toLowerCase().contains('prescribe') ||
              _recognizedText.toLowerCase().contains('add') ||
              _recognizedText.toLowerCase().contains('that\'s it') ||
              _recognizedText.toLowerCase().contains('done')) {
            _processVoiceCommand(_recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      _speechTimeoutTimer?.cancel();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processVoiceCommand(String text) {
    if (text.isEmpty) return;

    _stopListening();

    debugPrint('Processing voice command: $text');

    final parsedData = _parseVoiceCommand(text);
    _applyParsedDataToForm(parsedData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice command processed: ${text.substring(0, text.length > 50 ? 50 : text.length)}...'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ),
    );
  }

  Map<String, dynamic> _parseVoiceCommand(String text) {
    final result = {
      'medicine': '',
      'strength': '',
      'dosage': '',
      'unit': '',
      'frequency': '',
      'duration': '',
      'instruction': '',
    };

    text = text.toLowerCase();

    // 1. Extract medicine name and strength
    final medicinePattern = RegExp(r'([a-zA-Z]+)\s*(\d+)\s*(mg|gram|g|ml|tablet|capsule)?', caseSensitive: false);
    final medicineMatches = medicinePattern.allMatches(text).toList();
    
    if (medicineMatches.isNotEmpty) {
      final match = medicineMatches[0];
      result['medicine'] = '${match.group(1)!.toUpperCase()} ${match.group(2)!}';
      result['strength'] = match.group(2) ?? '';
      
      if (match.group(3) != null) {
        result['unit'] = match.group(3)!.toUpperCase();
      }
    }

    // 2. Extract duration
    final durationPattern = RegExp(r'(\d+)\s*(day|days|week|weeks|month|months)', caseSensitive: false);
    final durationMatch = durationPattern.firstMatch(text);
    if (durationMatch != null) {
      result['duration'] = durationMatch.group(1)!;
    } else {
      final numberPattern = RegExp(r'\b([1-9]|[12][0-9]|30)\b');
      final numbers = numberPattern.allMatches(text).toList();
      if (numbers.isNotEmpty) {
        for (var match in numbers) {
          final num = match.group(1)!;
          if (!result['medicine']!.contains(num)) {
            result['duration'] = num;
            break;
          }
        }
      }
    }

    String frequency = '';
    
    bool hasMorning = text.contains('morning');
    bool hasAfternoon = text.contains('afternoon') || text.contains('noon') || text.contains('lunch');
    bool hasNight = text.contains('night') || text.contains('evening') || text.contains('dinner') || text.contains('bedtime');
    bool hasOnce = text.contains('once') || text.contains('one time') || text.contains('daily');
    bool hasTwice = text.contains('twice') || text.contains('two times') || text.contains('two times a day') || text.contains('twice a day');
    bool hasThrice = text.contains('thrice') || text.contains('three times') || text.contains('three times a day')|| text.contains('thrice a day');
    
    
    if (hasOnce) {
      frequency = '0-0-1';
    } else if (hasTwice) {
      frequency = '1-0-1';
    } else if (hasThrice) {
      frequency = '1-1-1';
    } else {
      if (hasMorning && hasNight && !hasAfternoon) {
        frequency = '1-0-1';
      } else if (hasMorning && hasAfternoon && hasNight) {
        frequency = '1-1-1';
      } else if (hasMorning && !hasAfternoon && !hasNight) {
        frequency = '1-0-0';
      } else if (!hasMorning && !hasAfternoon && hasNight) {
        frequency = '0-0-1';
      } else if (!hasMorning && hasAfternoon && !hasNight) {
        frequency = '0-1-0';
      } else if (hasMorning && hasAfternoon && !hasNight) {
        frequency = '1-1-0';
      } else if (!hasMorning && hasAfternoon && hasNight) {
        frequency = '0-1-1';
      }
    }
    
    result['frequency'] = frequency;

  
    String instruction = '';
    
    if (text.contains('before food') || text.contains('before meal') || text.contains('before lunch') || text.contains('before dinner')) {
      instruction = 'Before Food';
    } else if (text.contains('after food') || text.contains('after meal') || text.contains('after lunch') || text.contains('after dinner')) {
      instruction = 'After Food';
    } else if (text.contains('empty stomach')) {
      instruction = 'Empty Stomach';
    } else if (text.contains('with milk')) {
      instruction = 'With Milk';
    } else if (text.contains('with water')) {
      instruction = 'With Water';
    }
    
    result['instruction'] = instruction;

    return result;
  }

  void _applyParsedDataToForm(Map<String, dynamic> parsedData) {
    setState(() {
      _voiceCommandApplied = true;
      
      if (parsedData['medicine'].isNotEmpty) {
        medicineController.text = parsedData['medicine'];
        _typeAheadController.text = parsedData['medicine'];
        _fetchMedicineDetailsWithVoiceData(parsedData['medicine'].split(' ')[0], parsedData);
      }

      if (parsedData['strength'].isNotEmpty) {
        strengthController.text = parsedData['strength'];
      }

      if (parsedData['unit'].isNotEmpty) {
        selectedUnit = parsedData['unit'];
        for (var unit in units) {
          if (unit.toLowerCase().contains(parsedData['unit'].toLowerCase()) ||
              parsedData['unit'].toLowerCase().contains(unit.toLowerCase())) {
            selectedUnit = unit;
            break;
          }
        }
      }

     
      if (parsedData['duration'].isNotEmpty) {
        durationController.text = parsedData['duration'];
        _calculateQuantity(); 
      }

      if (parsedData['frequency'].isNotEmpty) {
        selectedFrequency = parsedData['frequency'];
        _calculateQuantity(); 
      }

      if (parsedData['instruction'].isNotEmpty) {
        selectedInstruction = parsedData['instruction'];
        selectedDosageTime = parsedData['instruction'];
        
        for (var time in dosageTimes) {
          if (time.toLowerCase().contains(parsedData['instruction'].toLowerCase()) ||
              parsedData['instruction'].toLowerCase().contains(time.toLowerCase())) {
            selectedDosageTime = time;
            selectedInstruction = time;
            break;
          }
        }
      }
      if (doseController.text.isEmpty) {
        doseController.text = '1';
      }
    });
  }

  Future<void> _fetchMedicineDetailsWithVoiceData(String medicineName, Map<String, dynamic> voiceData) async {
    try {
      final details = await MedicineService.fetchMedicineDetails(medicineName);
      if (details != null) {
        medicineDetails = details;
        if (mounted) {
          setState(() {
            
            // 1. Basic Fields - only if voice didn't provide
            if (!_voiceCommandApplied || dosageController.text.isEmpty) {
              if (details['weight'] != null) dosageController.text = details['weight']?.toString() ?? '';
            }
            
            if (!_voiceCommandApplied || strengthController.text.isEmpty) {
              if (details['strength'] != null) strengthController.text = details['strength']?.toString() ?? '';
            }
            
            if (doseController.text.isEmpty) {
              if (details['dose'] != null) doseController.text = details['dose']?.toString() ?? '1';
            }

            // 2. Unit - only if voice didn't provide
            if ((!voiceData.containsKey('unit') || voiceData['unit']!.isEmpty) && details['unit'] != null) {
              selectedUnit = details['unit']?.toString();
              selectedUnitId = details['unitid'] is int ? details['unitid'] : int.tryParse('${details['unitid']}');
            }

            // 3. Frequency - only if voice didn't provide
            if (voiceData['frequency']!.isEmpty && details['dosefreq'] != null && details['dosefreq'].toString().isNotEmpty) {
              selectedFrequency = details['dosefreq']?.toString();
            }

            // 4. Route - always from API since voice doesn't specify route
            if (details['route'] != null && details['route'].toString().isNotEmpty) {
              selectedRoute = details['route']?.toString();
            } else if (selectedRoute == null && routes.isNotEmpty) {
              selectedRoute = 'ORAL'; 
            }
            if (voiceData['instruction']!.isEmpty) {
              if (details['dosageTime'] != null) {
                selectedDosageTime = details['dosageTime']?.toString();
                selectedInstruction = details['dosageTime']?.toString();
              } else if (details['instruction'] != null) {
                selectedDosageTime = details['instruction']?.toString();
                selectedInstruction = details['instruction']?.toString();
              } else if (dosageTimes.isNotEmpty) {
                selectedDosageTime = dosageTimes.first;
                selectedInstruction = dosageTimes.first;
              }
            }
            if (voiceData['duration']!.isEmpty) {
              if (details['days'] != null) {
                durationController.text = details['days']?.toString() ?? '';
              }
            }
            _calculateQuantity();
          });
          Future.microtask(() => _calculateQuantity());
        }
      }
    } catch (e) {
      debugPrint("Error fetching medicine details: $e");
    }
  }

  Future<void> _fetchMedicineDetails(String medicineName) async {
    try {
      final details = await MedicineService.fetchMedicineDetails(medicineName);
      if (details != null) {
        medicineDetails = details;
        if (mounted) {
          setState(() {
            _voiceCommandApplied = false; 
            
            // 1. Basic Fields
            if (details['weight'] != null) dosageController.text = details['weight']?.toString() ?? '';
            if (details['strength'] != null) strengthController.text = details['strength']?.toString() ?? '';
            if (details['dose'] != null) doseController.text = details['dose']?.toString() ?? '1';

            // 2. Unit
            if (details['unit'] != null) {
              selectedUnit = details['unit']?.toString();
              selectedUnitId = details['unitid'] is int ? details['unitid'] : int.tryParse('${details['unitid']}');
            }

            // 3. Frequency
            if (details['dosefreq'] != null && details['dosefreq'].toString().isNotEmpty) {
              selectedFrequency = details['dosefreq']?.toString();
            }

            // 4. Route
            if (details['route'] != null && details['route'].toString().isNotEmpty) {
              selectedRoute = details['route']?.toString();
            } else if (selectedRoute == null && routes.isNotEmpty) {
              selectedRoute = 'ORAL'; 
            }

            // 5. Instruction
            if (details['dosageTime'] != null) {
              selectedDosageTime = details['dosageTime']?.toString();
              selectedInstruction = details['dosageTime']?.toString();
            } else if (details['instruction'] != null) {
              selectedDosageTime = details['instruction']?.toString();
              selectedInstruction = details['instruction']?.toString();
            } else if (dosageTimes.isNotEmpty) {
              selectedDosageTime = dosageTimes.first;
              selectedInstruction = dosageTimes.first;
            }

            // 6. Duration
            if (details['days'] != null) {
              durationController.text = details['days']?.toString() ?? '';
            }

            // 7. Quantity
            _calculateQuantity();
          });
          Future.microtask(() => _calculateQuantity());
        }
      }
    } catch (e) {
      debugPrint("Error fetching medicine details: $e");
    }
  }

  void _calculateQuantity() {
    if (selectedFrequency != null && selectedFrequency!.isNotEmpty && durationController.text.isNotEmpty) {
      try {
        final duration = int.tryParse(durationController.text) ?? 0;
        if (duration > 0) {
          final parts = selectedFrequency!.split('-').where((p) => p.trim().isNotEmpty).toList();

          if (parts.isNotEmpty && parts.length <= 10) {
            int dailyDose = 0;
            for (String part in parts) {
              final parsed = int.tryParse(part) ?? double.tryParse(part)?.toInt() ?? 0;
              dailyDose += parsed;
            }
            final totalQuantity = dailyDose * duration;
            if (mounted) {
              setState(() {
                qtyController.text = totalQuantity.toString();
              });
            }
          } else {
            if (mounted) {
              setState(() {
                qtyController.text = duration.toString();
              });
            }
          }
        } else {
          if (mounted) setState(() => qtyController.text = '');
        }
      } catch (e) {
        debugPrint('Error calculating quantity: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          if (durationController.text.isEmpty) qtyController.text = '';
        });
      }
    }
  }

  Future<void> _loadDynamicData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _patientId = _patient.patientid; 
        _clientId = _patient.clientId;
        _admissionId = _patient.admissionId; 
        
        _practitionerId = _patient.practitionerid ?? widget.practitionerId ?? prefs.getString('practitionerId') ?? '';
        
        _userId = prefs.getString('userId') ?? 'aureus';
        _locationId = int.tryParse(prefs.getString('locationId') ?? '');
        _wardId = int.tryParse(prefs.getString('wardId') ?? '');
        _bedId = _patient.bedid; 
        
        // debugPrint('=== LOADED PATIENT DATA FOR PRESCRIPTION ===');
        // debugPrint('Patient ID: $_patientId');
        // debugPrint('Client ID: $_clientId');
        // debugPrint('Admission ID: $_admissionId');
        // debugPrint('Practitioner ID: $_practitionerId');
        // debugPrint('Bed ID: $_bedId');
        // debugPrint('============================================');
      });
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
      final cached = await UnitService.getCachedUnits();
      if (mounted) {
        setState(() {
          units = cached.map((e) => e.toString()).toSet().toList();
          unitsLoading = false;
        });
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
      final cached = await FrequencyService.getCachedData();
      if (mounted) {
        setState(() {
          frequencies = (cached['frequencies'] ?? []).map((e) => e.toString()).toSet().toList();
          routes = (cached['routes'] ?? []).map((e) => e.toString()).toSet().toList();
          dosageTimes = (cached['dosageTimes'] ?? []).map((e) => e.toString()).toSet().toList();
          frequencyDataLoading = false;
        });
      }
    }
  }

  Future<List<String>> _getMedicineSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      return await MedicineService.fetchMedicines(query: pattern);
    } catch (e) {
      return await MedicineService.getCachedMedicines();
    }
  }

  void _addPrescriptionItem() async {
    if (_prescriptionItems.length >= _maxMedicineLimit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limit Reached"), backgroundColor: Colors.red,
       duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
      return;
    }
    if (medicineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a medicine"),
       duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
      return;
    }

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

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
        "caldose": 0, "catalogueid": safeParseInt(medicineDetails['catalogueid']),
        "days": int.tryParse(durationController.text) ?? 5,
        "dosage": safeParseDouble(dosageController.text),
        "dose": doseController.text.isNotEmpty ? doseController.text : "1",
        "dosefreq": selectedFrequency ?? "1-0-1",
        "frequencyid": safeParseInt(medicineDetails['frequencyid']),
        "genericname": medicineDetails['genericname'] ?? "",
        "id": safeParseInt(medicineDetails['id']), "iswbd": 0,
        "medicineUnit": selectedUnitId ?? 0, "medicine_name": medicineController.text,
        "qty": int.tryParse(qtyController.text) ?? 1, "remark": remarkController.text,
        "route": selectedRoute ?? "ORAL", "strength": safeParseDouble(strengthController.text),
      };

      final response = await AddMedicineService.postMedicineDetails(medicineBody);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _prescriptionItems.add({
          'medicine': medicineController.text,
          'dosage': dosageController.text, 'unit': selectedUnit,
          'strength': strengthController.text, 'frequency': selectedFrequency,
          'dose': doseController.text, 'route': selectedRoute,
          'instruction': selectedDosageTime, 'duration': durationController.text,
          'quantity': qtyController.text, 'remark': remarkController.text,
          'apiResponse': response, 'medicineBody': medicineBody,
        });
      });
      _clearForm();

    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"),
       duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
    }
  }

  void _savePrescription() async {
    if (_prescriptionItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add medicine"), backgroundColor: Colors.orange,
       duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
          ),
          );
      return;
    }

    // Validate required patient data
    if (_admissionId == null || _admissionId!.isEmpty || _admissionId == '0') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Patient admission data is missing. Please select a patient from IPD dashboard."),
        backgroundColor: Colors.red,
         duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
      debugPrint('ERROR: Missing admission data for prescription');
      debugPrint('  admissionId: $_admissionId');
      debugPrint('  patientId: $_patientId');
      debugPrint('  clientId: $_clientId');
      return;
    }

    if (_practitionerId == null || _practitionerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Practitioner data is missing. Please select a patient from IPD dashboard."),
        backgroundColor: Colors.red,
         duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
      debugPrint('ERROR: Missing practitioner data for prescription');
      debugPrint('  practitionerId: $_practitionerId');
      return;
    }

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRemarksList = await AddMedicineService.getRemarks();
      final remarksString = savedRemarksList.isNotEmpty ? savedRemarksList.join(', ') : '';

      final List<Map<String, dynamic>> prescriptionMedicines = _prescriptionItems.map((item) {
        final medicineBody = item['medicineBody'] as Map<String, dynamic>;
        return {
          "categoryid": 0, "code": "", "datetime": "", "days": medicineBody['days']?.toString() ?? "5",
          "deliver_statuss": 0, "deliverd_datetime": "", "deliverd_userid": "", "dispriscsrno": "",
          "dosage": medicineBody['dosage']?.toString() ?? "0.00", "dose": medicineBody['dosefreq']?.toString() ?? "1-0-1",
          "dr_qty": medicineBody['qty']?.toString() ?? "1", "frequency": medicineBody['dosefreq']?.toString() ?? "1-0-1",
          "frequency_id": medicineBody['frequencyid'] ?? 0, "frequency_name": item['instruction'] ?? "Not specified",
          "id": medicineBody['id'] ?? 0, "instructions": item['instruction'] ?? "", "intreatmentgiven": 0,
          "ipdremovedt": "", "ipdremoveuserid": "", "ipdtimeshow": "", "isipdremove": 0, "isnurseprisc": 0,
          "masterdose": "0", "medicine_id": medicineBody['catalogueid'] ?? 0, "medicinename": medicineBody['medicine_name'] ?? "",
          "nurse_qty": medicineBody['qty']?.toString() ?? "", "nurseuserid": "", "parentid": 0, "patientid": _clientId ?? _patientId,
          "practitionerid": _practitionerId, "priscdurationtype": "", "route": medicineBody['route'] ?? "ORAL",
          "specializationid": 0, "sqno": 0, "total": "", "type": "", "strength": medicineBody['strength'] ?? 0,
          "unitextension": item['unit'] ?? "", "remark": medicineBody['remark'] ?? "", "productMasterId": medicineBody['catalogueid'] ?? 0,
        };
      }).toList();

      final prescriptionBody = {
        "admission": "", "admission_id": _admissionId!, 
        "billno": 0, "remark": remarksString,
        "department": 0, "discharge": 0, "dosenotes": "", "dstatus": 0, "english": 0, "followupcount": 0,
        "followupdate": "", "followupstype": "", "fromtreatmentgiven": 0, "hindi": 0, "lastmodified": "",
        "location_s": 0, "locationid": _locationId, "opd_appointmentid": 0, "patientid": _clientId ?? _patientId,
        "pending_datetime": "", "pending_userid": "", "postpay": 0, "practitionerid": _practitionerId,
        "prisc_status": 0, "regional": 0, "specializationid": 0, "userid": _userId, "tpId": 0,
        "wardId": _wardId, "bedId": _bedId, "priscriptionmedicinelist": prescriptionMedicines,
        "request_from": 0, "surgeonList": [0], "clientId": _clientId ?? _patientId,
      };

      // debugPrint('=== PRESCRIPTION SAVE BODY ===');
      // debugPrint('admission_id: ${prescriptionBody['admission_id']}');
      // debugPrint('patientid: ${prescriptionBody['patientid']}');
      // debugPrint('clientId: ${prescriptionBody['clientId']}');
      // debugPrint('practitionerid: ${prescriptionBody['practitionerid']}');
      // debugPrint('bedId: ${prescriptionBody['bedId']}');
      // debugPrint('============================');

      await SavePrescriptionService.savePrescription(prescriptionBody);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"), backgroundColor: Colors.green,
       duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
      setState(() { _prescriptionItems.clear(); });
      await AddMedicineService.clearRemarks();
      _clearForm();
      if(mounted) Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red,
       duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Required for margin
          margin: EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
      ));
    }
  }

  void _showPrescriptionPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin:const EdgeInsets.only(bottom:20), decoration: BoxDecoration(color:Colors.grey[300], borderRadius:BorderRadius.circular(10))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Prescription List", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("${_prescriptionItems.length}/$_maxMedicineLimit", style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _prescriptionItems.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _prescriptionItems[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                    child: Row(
                      children: [
                         CircleAvatar(
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          radius: 14,
                          child: Text("${index + 1}", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['medicine'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text("${item['dosage']}${item['unit']} | ${item['frequency']} | ${item['duration']} Days", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() => _prescriptionItems.removeAt(index));
                            Navigator.pop(context);
                            _showPrescriptionPopup();
                          },
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearForm() {
    medicineController.clear();
    _typeAheadController.clear();
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
      _voiceCommandApplied = false;
    });
  }


  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: type,
            maxLines: maxLines,
            readOnly: readOnly,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 18),
              border: InputBorder.none,
              isDense: true,
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String) onSelect,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            if (_typeAheadFocusNode.hasFocus) {
              _typeAheadFocusNode.unfocus();
            }

            FocusScope.of(context).unfocus();
            Future.delayed(const Duration(milliseconds: 50), () {
              _showSmartSelectionSheet(label, items, onSelect);
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), 
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: value != null ? const Color(0xFF1A237E) : Colors.grey[500], size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value ?? "Select",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: value != null ? Colors.black87 : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSmartSelectionSheet(String title, List<String> items, Function(String) onSelect) {
   final List<String> suggestions = items.length > 6 ? items.sublist(0, 6) : [];
    final List<String> remainingItems = items;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("Select $title", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 15),
              if (suggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text("Suggested", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions.map((item) {
                      return GestureDetector(
                        onTap: () {
                          onSelect(item);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6), 
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFC5CAE9)),
                          ),
                          child: Text(
                            item,
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A237E), fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1, height: 1),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                child: Text("All Options", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              ),

              Expanded(
                child: items.isEmpty
                ? Center(child: Text("No items available", style: GoogleFonts.poppins(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: remainingItems.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                        ),
                        title: Text(remainingItems[index], style: GoogleFonts.poppins(fontSize: 14)),
                        onTap: () {
                          onSelect(remainingItems[index]);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBarWithVoice() {
    return TypeAheadField<String>(
      controller: _typeAheadController,
      focusNode: _typeAheadFocusNode,
      suggestionsCallback: _getMedicineSuggestions,
      builder: (context, controller, focusNode) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search Medicine or use voice...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E)),
                    suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                          onPressed: () {
                            controller.clear();
                            medicineController.clear();
                            _clearForm();
                          }
                        )
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    if (medicineController.text != val) {
                      medicineController.text = val;
                      _voiceCommandApplied = false; 
                    }
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  icon: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: _isListening ? Colors.red : const Color(0xFF1A237E),
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red.withOpacity(0.1) : const Color(0xFF1A237E).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      itemBuilder: (context, suggestion) => ListTile(
        leading: const Icon(Icons.medication, size: 18, color: Color(0xFF1A237E)),
        title: Text(suggestion, style: GoogleFonts.poppins(fontSize: 13)),
        dense: true,
      ),
      onSelected: (suggestion) {
        medicineController.text = suggestion;
        _typeAheadController.text = suggestion;
        _typeAheadFocusNode.unfocus();
        _voiceCommandApplied = false; 
        _fetchMedicineDetails(suggestion);
      },
    );
  }

  Widget _buildVoiceCommandIndicator() {
    if (!_isListening && _recognizedText.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isListening ? Colors.blue[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isListening ? Colors.blue[100]! : Colors.green[100]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.check_circle,
            color: _isListening ? Colors.blue : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isListening ? 'Listening: $_recognizedText' : 'Voice command processed',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _isListening ? Colors.blue[800] : Colors.green[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isListening)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
              ),
            ),
        ],
      ),
    );
  }

  void _showVoiceTutorial() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Voice Command Examples',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 15),
              _buildVoiceExample(
                'Basic Medicine:',
                'Dolo 650, 5 days, morning and night',
              ),
              _buildVoiceExample(
                'With Instructions:',
                'Paracetamol 500 mg, 3 days, after food, twice daily',
              ),
              _buildVoiceExample(
                'Multiple Times:',
                'Azithromycin, once daily, 3 days, before food',
              ),
              _buildVoiceExample(
                'Complete Prescription:',
                'Amoxicillin 250 mg, 7 days, morning afternoon night after lunch',
              ),
              const SizedBox(height: 20),
              Text(
                'Tips:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTip('Speak clearly and naturally'),
                    _buildTip('Include medicine name and strength if known'),
                    _buildTip('Specify duration in days (e.g., 5 days)'),
                    _buildTip('Mention frequency (morning, afternoon, night, lunch, dinner)'),
                    _buildTip('Add instructions like "after food", "empty stomach"'),
                    _buildTip('Say "prescribe" or "add" to complete'),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startListening();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Try Voice Command',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_speechAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Note: Voice recognition may not be available on this device or emulator.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoiceExample(String title, String example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              example,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  const Color darkBlue = Color(0xFF1A237E);
    const Color bgGrey = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 15, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              color: darkBlue,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
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
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Req Prescription", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          Text(_patient.patientname, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                          if (_patient.ipdNo.isNotEmpty && _patient.ipdNo != 'N/A')
                            Text(
                              "IPD: ${_patient.ipdNo} | Bed: ${_patient.bedname}",
                              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showVoiceTutorial,
                      icon: const Icon(Icons.help_outline, color: Colors.white70, size: 22),
                      tooltip: 'Voice command help',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              
                _buildSearchBarWithVoice(),
                _buildVoiceCommandIndicator(),
                if (medicineDetails['genericname'] != null && medicineDetails['genericname'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text("Generic: ${medicineDetails['genericname']}", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    "Admission ID: $_admissionId | Patient ID: $_patientId",
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5), fontSize: 9),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                 if (medicineController.text.isEmpty) ...[
                    GestureDetector(
                      onTap: _showVoiceTutorial,
                      child: Container(
                        margin: const EdgeInsets.only(top: 50),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.mic,
                              size: 60,
                              color: Colors.blue[300],
                            ),
                            const SizedBox(height: 15),
                            Text(
                              "Try Voice Command",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap microphone icon or say:\n\"Dolo 650, 5 days, morning and night\"",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: _startListening,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Text(
                                  'Start Voice Input',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            if (!_speechAvailable)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  'Voice recognition may not be available on this device',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (medicineController.text.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Dosage & Strength", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                          const SizedBox(height: 8), 
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildSelectableField(
                                  value: selectedUnit,
                                  items: units,
                                  label: "Unit",
                                  icon: Icons.scale,
                                  onSelect: (v) => setState(() => selectedUnit = v),
                                )
                              ),
                              const SizedBox(width: 8), 
                              Expanded(
                                flex: 2,
                                child: _buildModernInput(
                                  controller: dosageController,
                                  label: "Dosage",
                                  icon: Icons.numbers,
                                  type: TextInputType.number,
                                  focusNode: _dosageFocusNode,
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), 
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildSelectableField(
                                  value: selectedRoute,
                                  items: routes,
                                  label: "Route",
                                  icon: Icons.alt_route,
                                  onSelect: (v) => setState(() => selectedRoute = v),
                                )
                              ),
                              const SizedBox(width: 8), 
                              Expanded(
                                flex: 2,
                                child: _buildModernInput(
                                  controller: strengthController,
                                  label: "Strength",
                                  icon: Icons.bolt,
                                  focusNode: _strengthFocusNode,
                                )
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(11), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Schedule & Timing", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                          const SizedBox(height: 8), 
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildSelectableField(
                                  value: selectedFrequency,
                                  items: frequencies,
                                  label: "Frequency",
                                  icon: Icons.access_time_filled,
                                  onSelect: (v) { setState(() => selectedFrequency = v); _calculateQuantity(); },
                                )
                              ),
                              const SizedBox(width: 8), 
                              Expanded(
                                flex: 2,
                                child: _buildModernInput(
                                  controller: durationController,
                                  label: "Days",
                                  icon: Icons.calendar_today,
                                  type: TextInputType.number,
                                  focusNode: _durationFocusNode,
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), 
                          _buildSelectableField(
                            value: selectedDosageTime,
                            items: dosageTimes,
                            label: "Instruction",
                            icon: Icons.description,
                            onSelect: (v) => setState(() { selectedDosageTime = v; selectedInstruction = v; }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11), 
                    Container(
                      padding: const EdgeInsets.all(11), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Remarks", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                              if (qtyController.text.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                                  child: Text("Total Qty: ${qtyController.text}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                )
                            ],
                          ),
                          const SizedBox(height: 8), 
                          _buildModernInput(
                            controller: remarkController,
                            label: "",
                            icon: Icons.edit_note,
                            maxLines: 2,
                            focusNode: _remarkFocusNode,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))]),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _addPrescriptionItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: darkBlue,
                    side: const BorderSide(color: darkBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text("Add +", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   onPressed: _prescriptionItems.isNotEmpty ? _showPrescriptionPopup : null,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey[100],
                     foregroundColor: Colors.black87,
                     padding: const EdgeInsets.symmetric(vertical: 14),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     elevation: 0,
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.list, size: 18),
                       if(_prescriptionItems.isNotEmpty) ...[
                         const SizedBox(width: 4),
                         Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text("${_prescriptionItems.length}", style: const TextStyle(fontSize: 10, color: Colors.white, height: 1)))
                       ]
                     ],
                   ),
                 ),
               ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _savePrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: darkBlue.withOpacity(0.3),
                  ),
                  child: Text("Save", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}