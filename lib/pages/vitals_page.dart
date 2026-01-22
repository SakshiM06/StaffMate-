import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VitalsPage extends StatefulWidget {
  final Patient patient;
  
  const VitalsPage({super.key, required this.patient});

  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  // Original controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _hrController = TextEditingController();
  final TextEditingController _rrController = TextEditingController();
  final TextEditingController _sysBpController = TextEditingController();
  final TextEditingController _diaBpController = TextEditingController();
  final TextEditingController _rbsController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  
  // Validation errors
  final Map<String, String?> _fieldErrors = {
    'temperature': null,
    'heartRate': null,
    'respiratoryRate': null,
    'systolicBp': null,
    'diastolicBp': null,
    'rbs': null,
    'spo2': null,
  };
  
  // Focus nodes for field navigation
  final List<FocusNode> _focusNodes = List.generate(7, (index) => FocusNode());
  int _currentFieldIndex = 0;
  
  // Speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  Timer? _speechTimeoutTimer;
  
  // Original variables
  String _selectedHH = '00';
  String _selectedMM = '00';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _vitalsMasterData = [];
  final IpdService _ipdService = IpdService();

  static const Color darkBlue = Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);
  
  // Voice overlay
  bool _showVoiceOverlay = false;
  String _voiceInstruction = 'Please speak Temperature';
  int _currentVoiceStep = 0;
  List<String> _voiceSteps = [];
  final Map<int, String> _voiceCollectedValues = {};
  bool _isProcessingVoice = false;
  bool _isVoiceInputComplete = false;

  // Field patterns for voice recognition
  final List<Map<String, dynamic>> _vitalPatterns = [
    {
      'label': 'Temperature',
      'controller': null,
      'controllerIndex': 0,
      'hint': '98.6',
      'suffix': '°F',
      'id': '1',
      'fieldName': 'temperature',
    },
    {
      'label': 'Heart Rate',
      'controller': null,
      'controllerIndex': 1,
      'hint': '72',
      'suffix': 'bpm',
      'id': '2',
      'fieldName': 'heartRate',
    },
    {
      'label': 'Systolic BP',
      'controller': null,
      'controllerIndex': 2,
      'hint': '120',
      'suffix': 'mmHg',
      'id': '4',
      'fieldName': 'systolicBp',
    },
    {
      'label': 'Diastolic BP',
      'controller': null,
      'controllerIndex': 3,
      'hint': '80',
      'suffix': 'mmHg',
      'id': '5',
      'fieldName': 'diastolicBp',
    },
    {
      'label': 'Respiratory Rate',
      'controller': null,
      'controllerIndex': 4,
      'hint': '18',
      'suffix': '/min',
      'id': '3',
      'fieldName': 'respiratoryRate',
    },
    {
      'label': 'SpO2',
      'controller': null,
      'controllerIndex': 5,
      'hint': '98',
      'suffix': '%',
      'id': '13',
      'fieldName': 'spo2',
    },
    {
      'label': 'RBS',
      'controller': null,
      'controllerIndex': 6,
      'hint': '100',
      'suffix': 'mg/dL',
      'id': '6',
      'fieldName': 'rbs',
    },
  ];

  // Range values for validation
  final Map<String, Map<String, dynamic>> _vitalRanges = {
    'temperature': {'min': 90.0, 'max': 110.0, 'unit': '°F'},
    'heartRate': {'min': 30, 'max': 200, 'unit': 'bpm'},
    'respiratoryRate': {'min': 6, 'max': 60, 'unit': '/min'},
    'systolicBp': {'min': 70, 'max': 250, 'unit': 'mmHg'},
    'diastolicBp': {'min': 40, 'max': 150, 'unit': 'mmHg'},
    'rbs': {'min': 20, 'max': 600, 'unit': 'mg/dL'},
    'spo2': {'min': 70, 'max': 100, 'unit': '%'},
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(now); 
    _selectedHH = DateFormat('HH').format(now);
    _selectedMM = DateFormat('mm').format(now);
    
    // Set controllers
    _vitalPatterns[0]['controller'] = _tempController;
    _vitalPatterns[1]['controller'] = _hrController;
    _vitalPatterns[2]['controller'] = _sysBpController;
    _vitalPatterns[3]['controller'] = _diaBpController;
    _vitalPatterns[4]['controller'] = _rrController;
    _vitalPatterns[5]['controller'] = _spo2Controller;
    _vitalPatterns[6]['controller'] = _rbsController;
    
    // Initialize voice steps
    _voiceSteps = _vitalPatterns.map((v) => v['label'] as String).toList();
    
    _loadVitalsMasterData();
    _initSpeech();
    
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() {
            _currentFieldIndex = i;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _speechTimeoutTimer?.cancel();
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // --- SPEECH RECOGNITION METHODS ---
  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_showVoiceOverlay && !_isProcessingVoice && !_isVoiceInputComplete) {
              // Restart listening if speech stopped unexpectedly
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_showVoiceOverlay && !_isVoiceInputComplete && mounted) {
                  _startVoiceListening();
                }
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          setState(() {
            _isListening = false;
          });
          _retrySpeechListening();
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

  void _retrySpeechListening() {
    if (_showVoiceOverlay && !_isVoiceInputComplete && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_showVoiceOverlay && !_isVoiceInputComplete && mounted) {
          _startVoiceListening();
        }
      });
    }
  }

  // --- VOICE OVERLAY METHODS ---
  void _startVoiceInput() {
    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _speech.hasPermission.then((hasPerm) {
      if (!hasPerm) {
        _speech.initialize().then((permissionGranted) {
          if (permissionGranted) {
            _startVoiceSequence();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission is required for voice input'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
        _startVoiceSequence();
      }
    });
  }

  void _startVoiceSequence() {
    setState(() {
      _showVoiceOverlay = true;
      _currentVoiceStep = 0;
      _voiceCollectedValues.clear();
      _isProcessingVoice = false;
      _isVoiceInputComplete = false;
      _voiceInstruction = 'Please speak ${_voiceSteps[_currentVoiceStep]} or say "Skip"';
      _recognizedText = '';
    });
    
    // Start listening after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _showVoiceOverlay) {
        _startVoiceListening();
      }
    });
  }

  void _hideVoiceOverlay() {
    setState(() {
      _showVoiceOverlay = false;
      _isListening = false;
      _isProcessingVoice = false;
      _isVoiceInputComplete = false;
    });
    _speech.stop();
    
    // Focus on first field for editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_voiceCollectedValues.isNotEmpty && mounted) {
        final firstKey = _voiceCollectedValues.keys.first;
        if (firstKey < _focusNodes.length) {
          setState(() {
            _currentFieldIndex = firstKey;
          });
          _focusNodes[firstKey].requestFocus();
        }
      }
    });
  }

  Future<void> _startVoiceListening() async {
    if (_isListening || _isProcessingVoice || _isVoiceInputComplete) return;

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _voiceInstruction = 'Listening... Speak ${_voiceSteps[_currentVoiceStep]} or say "Skip"';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });

          if (result.finalResult) {
            debugPrint('Final result: ${result.recognizedWords}');
            _processVoiceInputForCurrentStep(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      setState(() {
        _isListening = false;
      });
      _retrySpeechListening();
    }
  }

  void _processVoiceInputForCurrentStep(String text) {
    if (text.isEmpty || _isProcessingVoice) return;

    setState(() {
      _isProcessingVoice = true;
      _isListening = false;
    });

    debugPrint('Processing voice for ${_voiceSteps[_currentVoiceStep]}: $text');
    
    // Check if user wants to skip this field
    if (_isSkipCommand(text)) {
      _skipCurrentField();
      return;
    }
    
    // Extract numeric value
    final value = _extractNumericValue(text);
    
    if (value != null) {
      // Validate the value against the range
      final validationResult = _validateVoiceInput(_currentVoiceStep, value);
      
      if (validationResult['isValid'] == true) {
        // Store the collected value
        _voiceCollectedValues[_currentVoiceStep] = value;
        
        // Update the UI with the value
        _updateFieldWithValue(_currentVoiceStep, value);
        
        // Show success feedback
        _showVoiceStepSuccess(value);
        
        // Move to next step after delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _showVoiceOverlay) {
            _moveToNextVoiceStep();
          }
        });
      } else {
        // Show validation error
        final errorMessage = validationResult['message'] as String? ?? 'Value is outside allowed range';
        _showValidationError(errorMessage);
        
        // Restart listening after showing error
        setState(() {
          _voiceInstruction = errorMessage;
          _recognizedText = '';
          _isProcessingVoice = false;
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _showVoiceOverlay) {
            _startVoiceListening();
          }
        });
      }
    } else {
      // Couldn't extract value
      setState(() {
        _voiceInstruction = 'Could not understand. Please say ${_voiceSteps[_currentVoiceStep]} value or say "Skip". Example: "98.6"';
        _recognizedText = '';
        _isProcessingVoice = false;
      });
      
      // Restart listening after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    }
  }

  Map<String, dynamic> _validateVoiceInput(int stepIndex, String value) {
    final fieldName = _vitalPatterns[stepIndex]['fieldName'] as String;
    final range = _vitalRanges[fieldName];
    
    if (range == null) {
      return {'isValid': true};
    }

    final numValue = double.tryParse(value);
    if (numValue == null) {
      return {
        'isValid': false,
        'message': 'Please speak a valid number',
      };
    }

    if (numValue < range['min']) {
      return {
        'isValid': false,
        'message': 'Please select in range (${range['min']}-${range['max']})',
      };
    }

    if (numValue > range['max']) {
      return {
        'isValid': false,
        'message': 'Please select in range (${range['min']}-${range['max']})',
      };
    }

    return {'isValid': true};
  }

  void _showValidationError(String errorMessage) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isSkipCommand(String text) {
    final skipWords = ['skip', 'next', 'no', 'not needed', 'not required', 'pass'];
    final cleanText = text.toLowerCase().trim();
    return skipWords.contains(cleanText);
  }

  void _skipCurrentField() {
    // Show skip feedback
    _showSkipSuccess();
    
    // Move to next step after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _showVoiceOverlay) {
        _moveToNextVoiceStep();
      }
    });
  }

  void _showSkipSuccess() {
    final currentField = _voiceSteps[_currentVoiceStep];
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$currentField skipped'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
      ),
    );
    
    setState(() {
      _voiceInstruction = '$currentField skipped. Moving to next field...';
    });
  }

  String? _extractNumericValue(String text) {
    try {
      // Clean the text
      text = text.toLowerCase();
      
      // Replace spoken words with numbers
      final replacements = {
        'point': '.',
        'dot': '.',
        'zero': '0',
        'one': '1',
        'two': '2',
        'three': '3',
        'four': '4',
        'five': '5',
        'six': '6',
        'seven': '7',
        'eight': '8',
        'nine': '9',
        'ten': '10',
        'eleven': '11',
        'twelve': '12',
        'thirteen': '13',
        'fourteen': '14',
        'fifteen': '15',
        'sixteen': '16',
        'seventeen': '17',
        'eighteen': '18',
        'nineteen': '19',
        'twenty': '20',
        'thirty': '30',
        'forty': '40',
        'fifty': '50',
        'sixty': '60',
        'seventy': '70',
        'eighty': '80',
        'ninety': '90',
        'hundred': '00',
        'percent': '%',
      };
      
      for (final entry in replacements.entries) {
        text = text.replaceAll(entry.key, entry.value);
      }
      
      // Remove non-numeric characters except decimal point
      text = text.replaceAll(RegExp(r'[^\d\.]'), '');
      
      if (text.isNotEmpty) {
        return text;
      }
    } catch (e) {
      debugPrint('Error extracting numeric value: $e');
    }
    
    return null;
  }

  void _updateFieldWithValue(int stepIndex, String value) {
    final controller = _vitalPatterns[stepIndex]['controller'] as TextEditingController;
    
    if (mounted) {
      setState(() {
        controller.text = value;
      });
    }
  }

  void _showVoiceStepSuccess(String value) {
    final currentField = _voiceSteps[_currentVoiceStep];
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$currentField: $value recorded'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _moveToNextVoiceStep() {
    if (_currentVoiceStep < _voiceSteps.length - 1) {
      setState(() {
        _currentVoiceStep++;
        _isProcessingVoice = false;
        _recognizedText = '';
        _voiceInstruction = 'Please speak ${_voiceSteps[_currentVoiceStep]} or say "Skip"';
      });
      
      // Start listening for next step
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    } else {
      // All steps completed
      _completeVoiceInput();
    }
  }

  void _moveToPreviousVoiceStep() {
    if (_currentVoiceStep > 0) {
      setState(() {
        _currentVoiceStep--;
        _isProcessingVoice = false;
        _recognizedText = '';
        _voiceInstruction = 'Please speak ${_voiceSteps[_currentVoiceStep]} or say "Skip"';
      });
      
      // Remove the collected value for the current step
      _voiceCollectedValues.remove(_currentVoiceStep + 1);
      
      // Clear the field
      final controller = _vitalPatterns[_currentVoiceStep + 1]['controller'] as TextEditingController;
      if (mounted) {
        setState(() {
          controller.text = '';
        });
      }
      
      // Start listening for previous step
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    }
  }

  void _completeVoiceInput() {
    setState(() {
      _isVoiceInputComplete = true;
      _voiceInstruction = 'Voice input complete!';
      _isListening = false;
    });
    
    _speech.stop();
    
    // Show completion dialog after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showVoiceInputComplete();
      }
    });
  }

  void _showVoiceInputComplete() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Voice Input Complete!',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: darkBlue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully recorded ${_voiceCollectedValues.length} vital signs:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 10),
              ..._voiceCollectedValues.entries.map((entry) {
                final fieldName = _voiceSteps[entry.key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$fieldName: ${entry.value}',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Text(
                'Tap "Edit Values" to edit manually or "OK" to continue.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _hideVoiceOverlay();
              },
              child: Text('Edit Values', style: GoogleFonts.poppins(color: darkBlue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _hideVoiceOverlay();
              },
              child: Text('OK', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  // --- ORIGINAL METHODS ---

  Future<void> _loadVitalsMasterData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _ipdService.fetchVitalsMasterData();
      
      if (response['success'] == true) {
        final List<dynamic> masterData = response['data'] ?? [];
        
        _vitalsMasterData = masterData.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else {
            return <String, dynamic>{};
          }
        }).toList();
        
        debugPrint('Loaded ${_vitalsMasterData.length} vitals master items');
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load vitals data';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading vitals data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getVitalHint(String vitalId) {
    if (_vitalsMasterData.isEmpty) {
      return '(0-0)';
    }
    
    try {
      for (var vital in _vitalsMasterData) {
        final id = vital['id'].toString();
        if (id == vitalId) {
          final min = vital['min_value_f']?.toString() ?? '0';
          final max = vital['max_value_f']?.toString() ?? '0';
          return '($min-$max)';
        }
      }
    } catch (e) {
      debugPrint('Error getting vital hint: $e');
    }
    
    return '(0-0)';
  }

  Future<void> _onSaveVitals() async {
    setState(() {
      _errorMessage = null;
    });

    // Validation
    if (_dateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a date';
      });
      return;
    }

    // Check if all fields are empty
    bool allEmpty = _tempController.text.isEmpty &&
        _hrController.text.isEmpty &&
        _rrController.text.isEmpty &&
        _sysBpController.text.isEmpty &&
        _diaBpController.text.isEmpty &&
        _rbsController.text.isEmpty &&
        _spo2Controller.text.isEmpty;

    if (allEmpty) {
      setState(() {
        _errorMessage = 'Please enter at least one vital sign';
      });
      return;
    }

    String admissionId = widget.patient.admissionId.toString();
    
    if (admissionId.isEmpty || admissionId == '0') {
      final prefs = await SharedPreferences.getInstance();
      admissionId = prefs.getString('admissionid') ?? '';
    }
    
    if (admissionId.isEmpty || admissionId == '0') {
      setState(() {
        _errorMessage = 'Valid Admission ID not found. Please refresh patient data.';
      });
      return;
    }

    String patientId = widget.patient.patientId.toString();
    
    if (patientId.isEmpty) {
      patientId = widget.patient.id.toString();
    }
    
    if (patientId.isEmpty) {
      setState(() {
        _errorMessage = 'Patient ID not found in patient data.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vitalEntries = _prepareVitalEntries();

      if (vitalEntries.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter at least one vital sign';
          _isLoading = false;
        });
        return;
      }

      final response = await _ipdService.savePatientVitals(
        patientId: patientId,
        admissionId: admissionId,
        date: _dateController.text, 
        time: '$_selectedHH:$_selectedMM',
        vitalEntries: vitalEntries,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Vitals saved successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to save vitals.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _prepareVitalEntries() {
    final entries = <Map<String, dynamic>>[];
    
    if (_tempController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 1, 'finding': _tempController.text});
    }
    if (_hrController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 2, 'finding': _hrController.text});
    }
    if (_rrController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 3, 'finding': _rrController.text});
    }
    if (_sysBpController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 4, 'finding': _sysBpController.text});
    }
    if (_diaBpController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 5, 'finding': _diaBpController.text});
    }
    if (_rbsController.text.isNotEmpty) {
      entries.add({'vitalMasterId': 6, 'finding': _rbsController.text});
    }
    if (_spo2Controller.text.isNotEmpty) {
      entries.add({'vitalMasterId': 13, 'finding': _spo2Controller.text});
    }
    
    return entries;
  }

  // Validation for manual input
  void _validateManualInput(String fieldName, String value) {
    if (value.isEmpty) {
      setState(() {
        _fieldErrors[fieldName] = null;
      });
      return;
    }

    final range = _vitalRanges[fieldName];
    if (range == null) return;

    final numValue = double.tryParse(value);
    if (numValue == null) {
      setState(() {
        _fieldErrors[fieldName] = 'Please enter a valid number';
      });
      return;
    }

    if (numValue < range['min'] || numValue > range['max']) {
      setState(() {
        _fieldErrors[fieldName] = 'Please select in range (${range['min']}-${range['max']})';
      });
    } else {
      setState(() {
        _fieldErrors[fieldName] = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Capture Vitals",
              style: GoogleFonts.poppins(
                fontSize: 16, 
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.patient.patientname,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "IPD: ${widget.patient.ipdNo} | Ward: ${widget.patient.ward}",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _startVoiceInput,
            icon: const Icon(Icons.mic, color: Colors.white),
            tooltip: 'Voice input (step by step)',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showVoiceTutorial,
            tooltip: 'Voice instructions',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[100] ?? Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildSectionHeader("Date & Time"),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading ? null : () async {
                            DateTime? picked = await showDatePicker(
                              context: context, 
                              initialDate: DateTime.now(), 
                              firstDate: DateTime(2020), 
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(primary: darkBlue),
                                  ),
                                  child: child!,
                                );
                              }
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: bgGrey,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: darkBlue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _dateController.text,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bgGrey,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: darkBlue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '$_selectedHH:$_selectedMM',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildSectionHeader("Vital Signs"),
                
                // Updated Voice Input Box
                GestureDetector(
                  onTap: _startVoiceInput,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF64B5F6), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3364B5F6),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4D1A237E),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step-by-Step Voice Input',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: darkBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Speak each vital one by one. Say "Skip" to skip a field.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF3949AB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x1A1A237E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_right, color: darkBlue),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _tempController, 
                            label: "Temp F ${_getVitalHint('1')}", 
                            hint: "98.6", 
                            icon: Icons.thermostat, 
                            suffix: "°F",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[0],
                            fieldIndex: 0,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['temperature'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['temperature']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _hrController, 
                            label: "Heart Rate ${_getVitalHint('2')}", 
                            hint: "72", 
                            icon: Icons.monitor_heart, 
                            suffix: "bpm",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[1],
                            fieldIndex: 1,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['heartRate'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['heartRate']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _sysBpController, 
                            label: "Sys BP ${_getVitalHint('4')}", 
                            hint: "120", 
                            icon: Icons.arrow_upward, 
                            suffix: "mmHg",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[2],
                            fieldIndex: 2,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['systolicBp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['systolicBp']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _diaBpController, 
                            label: "Dia BP ${_getVitalHint('5')}", 
                            hint: "80", 
                            icon: Icons.arrow_downward, 
                            suffix: "mmHg",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[3],
                            fieldIndex: 3,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['diastolicBp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['diastolicBp']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _rrController, 
                            label: "Resp. Rate ${_getVitalHint('3')}", 
                            hint: "18", 
                            icon: Icons.air, 
                            suffix: "/min",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[4],
                            fieldIndex: 4,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['respiratoryRate'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['respiratoryRate']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernInput(
                            controller: _spo2Controller, 
                            label: "SpO2 ${_getVitalHint('13')}", 
                            hint: "98", 
                            icon: Icons.water_drop, 
                            suffix: "%",
                            keyboardType: TextInputType.number,
                            focusNode: _focusNodes[5],
                            fieldIndex: 5,
                            currentFieldIndex: _currentFieldIndex,
                          ),
                          if (_fieldErrors['spo2'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fieldErrors['spo2']!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernInput(
                      controller: _rbsController, 
                      label: "RBS ${_getVitalHint('6')}", 
                      hint: "100", 
                      icon: Icons.bloodtype, 
                      suffix: "mg/dL",
                      keyboardType: TextInputType.number,
                      focusNode: _focusNodes[6],
                      fieldIndex: 6,
                      currentFieldIndex: _currentFieldIndex,
                    ),
                    if (_fieldErrors['rbs'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _fieldErrors['rbs']!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Voice overlay - Updated to be transparent and centered
          if (_showVoiceOverlay) _buildVoiceOverlay(),

          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onSaveVitals,
            style: ElevatedButton.styleFrom(
              backgroundColor: darkBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
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
                : Text("Save Vitals", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0x66000000),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: const Color(0xD9000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: (_currentVoiceStep + 1) / _voiceSteps.length,
                        backgroundColor: const Color(0xFF424242),
                        color: Colors.blue,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Step ${_currentVoiceStep + 1} of ${_voiceSteps.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFBDBDBD),
                            ),
                          ),
                          Text(
                            '${((_currentVoiceStep + 1) / _voiceSteps.length * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFBDBDBD),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Animated microphone
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 140 : 120,
                  height: _isListening ? 140 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? const Color(0xFFE3F2FD) : Colors.white,
                    border: Border.all(
                      color: _isListening ? Colors.blue : const Color(0xFFE0E0E0),
                      width: _isListening ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(_isListening ? 0.3 : 0.1),
                        blurRadius: _isListening ? 20 : 10,
                        spreadRadius: _isListening ? 5 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessingVoice
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : Icon(
                            Icons.mic,
                            size: _isListening ? 60 : 50,
                            color: _isListening ? Colors.blue : const Color(0xFF757575),
                          ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Current field label
                Text(
                  _voiceSteps[_currentVoiceStep],
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Instruction text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _voiceInstruction,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Recognized text
                if (_recognizedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        _recognizedText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Collected value (if any)
                if (_voiceCollectedValues.containsKey(_currentVoiceStep))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x334CAF50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(
                      'Value: ${_voiceCollectedValues[_currentVoiceStep]}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Example hint with skip instruction
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Example:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFFBDBDBD),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getExampleHint(_currentVoiceStep)}\nOr say "Skip" to skip this field',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF90CAF9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Previous button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentVoiceStep > 0 && !_isProcessingVoice ? _moveToPreviousVoiceStep : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.white),
                          ),
                          child: Text(
                            'Previous',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _currentVoiceStep > 0 && !_isProcessingVoice ? Colors.white : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Skip button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessingVoice ? null : () {
                            _skipCurrentField();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.orange),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Next/Finish button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessingVoice 
                              ? null
                              : () {
                                  if (_voiceCollectedValues.containsKey(_currentVoiceStep)) {
                                    if (_currentVoiceStep < _voiceSteps.length - 1) {
                                      _moveToNextVoiceStep();
                                    } else {
                                      _completeVoiceInput();
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _voiceCollectedValues.containsKey(_currentVoiceStep) 
                                ? (_currentVoiceStep < _voiceSteps.length - 1 ? Colors.blue : Colors.green)
                                : const Color(0xFF757575),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessingVoice
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _voiceCollectedValues.containsKey(_currentVoiceStep)
                                      ? (_currentVoiceStep < _voiceSteps.length - 1 ? 'Next' : 'Finish')
                                      : 'Speak Value',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getExampleHint(int stepIndex) {
    switch (stepIndex) {
      case 0: // Temperature
        return '"98.6" or "ninety eight point six"';
      case 1: // Heart Rate
        return '"72" or "seventy two"';
      case 2: // Systolic BP
        return '"120" or "one twenty"';
      case 3: // Diastolic BP
        return '"80" or "eighty"';
      case 4: // Respiratory Rate
        return '"18" or "eighteen"';
      case 5: // SpO2
        return '"98" or "ninety eight"';
      case 6: // RBS
        return '"100" or "one hundred"';
      default:
        return 'Say the number clearly';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    TextInputType keyboardType = TextInputType.number,
    FocusNode? focusNode,
    int? fieldIndex,
    int? currentFieldIndex,
  }) {
    final isCurrentField = fieldIndex == currentFieldIndex;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const Spacer(),
            if (fieldIndex != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCurrentField ? darkBlue : Colors.grey[200] ?? Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${fieldIndex + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isCurrentField ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: bgGrey,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrentField ? darkBlue : Colors.grey[200] ?? Colors.grey,
              width: isCurrentField ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            enabled: !_isLoading,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: darkBlue, size: 18),
              suffixText: suffix,
              suffixStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              isDense: true,
            ),
            onChanged: (value) {
              final fieldName = _vitalPatterns[fieldIndex!]['fieldName'] as String;
              _validateManualInput(fieldName, value);
            },
          ),
        ),
      ],
    );
  }

  void _showVoiceTutorial() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
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
                'Step-by-Step Voice Guide',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 15),
              _buildVoiceExample(
                'How it works:',
                '1. Speak Temperature value or say "Skip"\n2. Click "Next" or say "Next"\n3. Speak Heart Rate value or say "Skip"\n4. Continue through all fields\nSay "Skip" for any field you don\'t need',
              ),
              _buildVoiceExample(
                'Examples for each field:',
                'Temperature: "98.6"\nHeart Rate: "72"\nSystolic BP: "120"\nDiastolic BP: "80"\nRespiratory Rate: "18"\nSpO2: "98"\nRBS: "100"\n\nSay "Skip" to skip any field',
              ),
              _buildVoiceExample(
                'Range Validation:',
                'Values are checked against valid ranges.\nIf value is outside range, you will be asked to speak a value within range.',
              ),
              _buildVoiceExample(
                'Skip commands:',
                '• "Skip" - Skip current field\n• "Next" - Skip to next\n• "No" - Don\'t record this\n• "Not needed" - Skip field\n• "Pass" - Skip this value',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startVoiceInput();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
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
                            'Start Voice Input',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
              border: Border.all(color: Colors.grey[200] ?? Colors.grey),
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
}