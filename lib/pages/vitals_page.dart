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

class _VitalsPageState extends State<VitalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              "Capture Vitals & Intake",
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
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF1A237E),
                unselectedLabelColor: Colors.white.withOpacity(0.8),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'VITAL SIGNS'),
                  Tab(text: 'INTAKE ASSESSMENT'),
                ],
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          VitalsTab(patient: widget.patient),
          IntakeAssessmentTab(patient: widget.patient),
        ],
      ),
    );
  }
}

// Vitals Tab - Original functionality
class VitalsTab extends StatefulWidget {
  final Patient patient;
  
  const VitalsTab({super.key, required this.patient});

  @override
  State<VitalsTab> createState() => _VitalsTabState();
}

class _VitalsTabState extends State<VitalsTab> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _hrController = TextEditingController();
  final TextEditingController _rrController = TextEditingController();
  final TextEditingController _sysBpController = TextEditingController();
  final TextEditingController _diaBpController = TextEditingController();
  final TextEditingController _rbsController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  
  final Map<String, String?> _fieldErrors = {
    'temperature': null,
    'heartRate': null,
    'respiratoryRate': null,
    'systolicBp': null,
    'diastolicBp': null,
    'rbs': null,
    'spo2': null,
  };
  
  final List<FocusNode> _focusNodes = List.generate(7, (index) => FocusNode());
  int _currentFieldIndex = 0;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  Timer? _speechTimeoutTimer;
  
  String _selectedHH = '00';
  String _selectedMM = '00';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _vitalsMasterData = [];
  final IpdService _ipdService = IpdService();

  static const Color darkBlue = Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);
  
  bool _showVoiceOverlay = false;
  String _voiceInstruction = 'Please speak Temperature';
  int _currentVoiceStep = 0;
  List<String> _voiceSteps = [];
  final Map<int, String> _voiceCollectedValues = {};
  bool _isProcessingVoice = false;
  bool _isVoiceInputComplete = false;

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
    
    _vitalPatterns[0]['controller'] = _tempController;
    _vitalPatterns[1]['controller'] = _hrController;
    _vitalPatterns[2]['controller'] = _sysBpController;
    _vitalPatterns[3]['controller'] = _diaBpController;
    _vitalPatterns[4]['controller'] = _rrController;
    _vitalPatterns[5]['controller'] = _spo2Controller;
    _vitalPatterns[6]['controller'] = _rbsController;
    
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

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_showVoiceOverlay && !_isProcessingVoice && !_isVoiceInputComplete && mounted) {
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
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
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
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
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
    
    if (_isSkipCommand(text)) {
      _skipCurrentField();
      return;
    }
    
    final value = _extractNumericValue(text);
    
    if (value != null) {
      final validationResult = _validateVoiceInput(_currentVoiceStep, value);
      
      if (validationResult['isValid'] == true) {
        _voiceCollectedValues[_currentVoiceStep] = value;
        _updateFieldWithValue(_currentVoiceStep, value);
        _showVoiceStepSuccess(value);
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _showVoiceOverlay) {
            _moveToNextVoiceStep();
          }
        });
      } else {
        final errorMessage = validationResult['message'] as String? ?? 'Value is outside allowed range';
        _showValidationError(errorMessage);
        
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
      setState(() {
        _voiceInstruction = 'Could not understand. Please say ${_voiceSteps[_currentVoiceStep]} value or say "Skip". Example: "98.6"';
        _recognizedText = '';
        _isProcessingVoice = false;
      });
      
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
    _showSkipSuccess();
    
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
      text = text.toLowerCase();
      
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
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    } else {
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
      
      _voiceCollectedValues.remove(_currentVoiceStep + 1);
      
      final controller = _vitalPatterns[_currentVoiceStep + 1]['controller'] as TextEditingController;
      if (mounted) {
        setState(() {
          controller.text = '';
        });
      }
      
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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

    if (_dateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a date';
      });
      return;
    }

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
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[100] ?? Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildSectionHeader("Date & Time"),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: bgGrey,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: darkBlue, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _dateController.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: darkBlue, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$_selectedHH:$_selectedMM',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
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

              const SizedBox(height: 16),

              _buildSectionHeader("Vital Signs"),
              
              GestureDetector(
                onTap: _startVoiceInput,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF64B5F6), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2264B5F6),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3D1A237E),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step-by-Step Voice Input',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Speak each vital one by one. Say "Skip" to skip a field.',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF3949AB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1A237E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.chevron_right, color: darkBlue, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              
              Column(
                children: [
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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['temperature']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['heartRate']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['systolicBp']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['diastolicBp']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['respiratoryRate']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Text(
                                  _fieldErrors['spo2']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                          padding: const EdgeInsets.only(top: 2, left: 4),
                          child: Text(
                            _fieldErrors['rbs']!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 60),
            ],
          ),
        ),

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

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -3))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSaveVitals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text("Save Vitals", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

Widget _buildVoiceOverlay() {
  return Positioned.fill(
    child: Container(
      color: const Color(0xCC000000), // Slightly darker background
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // Slightly smaller width
          constraints: const BoxConstraints(
            maxHeight: 500, // Fixed maximum height for consistency
            minHeight: 420,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Input',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Step ${_currentVoiceStep + 1} of ${_voiceSteps.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: _hideVoiceOverlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: (_currentVoiceStep + 1) / _voiceSteps.length,
                      backgroundColor: Colors.grey[200],
                      color: Colors.blue,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${((_currentVoiceStep + 1) / _voiceSteps.length * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Current field name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _voiceSteps[_currentVoiceStep],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A237E),
                  ),
                ),
              ),
              
              // Voice status/instruction
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _voiceInstruction,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _voiceInstruction.contains('Listening')
                        ? Colors.green
                        : _voiceInstruction.contains('Could not understand')
                            ? Colors.red
                            : Colors.grey[700],
                  ),
                ),
              ),
              
              // Mic animation/icon
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 80 : 60,
                  height: _isListening ? 80 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? const Color(0xFFE3F2FD) : Colors.grey[100],
                    border: Border.all(
                      color: _isListening ? Colors.blue : Colors.grey[300] ?? Colors.grey,
                      width: _isListening ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: _isProcessingVoice
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : Icon(
                            Icons.mic,
                            size: _isListening ? 32 : 28,
                            color: _isListening ? Colors.blue : Colors.grey[600],
                          ),
                  ),
                ),
              ),
              
              // Recognized text
              if (_recognizedText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                    ),
                    child: Text(
                      _recognizedText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              
              // Current value if captured
              if (_voiceCollectedValues.containsKey(_currentVoiceStep))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Value: ${_voiceCollectedValues[_currentVoiceStep]}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Example hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      'Example:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getExampleHint(_currentVoiceStep),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Or say "Skip" to skip this field',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Control buttons - FIXED to avoid overflow
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _currentVoiceStep > 0 && !_isProcessingVoice ? _moveToPreviousVoiceStep : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color: _currentVoiceStep > 0 && !_isProcessingVoice 
                                    ? const Color(0xFF1A237E) 
                                    : Colors.grey[300] ?? Colors.grey,
                              ),
                            ),
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _currentVoiceStep > 0 && !_isProcessingVoice 
                                    ? const Color(0xFF1A237E) 
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessingVoice ? null : () {
                              _skipCurrentField();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.orange),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Next/Finish button
                    SizedBox(
                      width: double.infinity,
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
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                                    ? (_currentVoiceStep < _voiceSteps.length - 1 ? 'Next Field' : 'Finish & Save')
                                    : 'Speak Now',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
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
      case 0: return '"98.6" or "ninety eight point six"';
      case 1: return '"72" or "seventy two"';
      case 2: return '"120" or "one twenty"';
      case 3: return '"80" or "eighty"';
      case 4: return '"18" or "eighteen"';
      case 5: return '"98" or "ninety eight"';
      case 6: return '"100" or "one hundred"';
      default: return 'Say the number clearly';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        title, 
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])
      ),
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
            Expanded(
              child: Text(
                label, 
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])
              ),
            ),
            if (fieldIndex != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isCurrentField ? darkBlue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${fieldIndex + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: isCurrentField ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: bgGrey,
            borderRadius: BorderRadius.circular(8),
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
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: darkBlue, size: 16),
              suffixText: suffix,
              suffixStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
}

// Intake Assessment Tab - Same as Vitals design
class IntakeAssessmentTab extends StatefulWidget {
  final Patient patient;
  
  const IntakeAssessmentTab({super.key, required this.patient});

  @override
  State<IntakeAssessmentTab> createState() => _IntakeAssessmentTabState();
}

class _IntakeAssessmentTabState extends State<IntakeAssessmentTab> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _fluidController = TextEditingController();
  final TextEditingController _tpnController = TextEditingController();
  final TextEditingController _bloodFilterController = TextEditingController();
  final TextEditingController _feedController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _urineController = TextEditingController();
  
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  int _currentFieldIndex = 0;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  
  bool _showVoiceOverlay = false;
  String _voiceInstruction = 'Please speak Fluid value';
  int _currentVoiceStep = 0;
  List<String> _voiceSteps = [];
  final Map<int, String> _voiceCollectedValues = {};
  bool _isProcessingVoice = false;
  bool _isVoiceInputComplete = false;

  final List<Map<String, dynamic>> _intakePatterns = [
    {
      'label': 'Fluid',
      'controller': null,
      'controllerIndex': 0,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'fluid',
    },
    {
      'label': 'TPN',
      'controller': null,
      'controllerIndex': 1,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'tpn',
    },
    {
      'label': 'Blood/PVE 40 H Filter',
      'controller': null,
      'controllerIndex': 2,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'bloodFilter',
    },
    {
      'label': 'Feed',
      'controller': null,
      'controllerIndex': 3,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'feed',
    },
    {
      'label': 'Medication',
      'controller': null,
      'controllerIndex': 4,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'medication',
    },
    {
      'label': 'Urine',
      'controller': null,
      'controllerIndex': 5,
      'hint': '0',
      'range': '0-0',
      'fieldName': 'urine',
    },
  ];

  static const Color darkBlue = Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);
  String _selectedHH = '13';
  String _selectedMM = '24';
  bool _isLoading = false;
  String? _errorMessage;
  final IpdService _ipdService = IpdService();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text = DateFormat('dd-MM-yyyy').format(now);
    
    _intakePatterns[0]['controller'] = _fluidController;
    _intakePatterns[1]['controller'] = _tpnController;
    _intakePatterns[2]['controller'] = _bloodFilterController;
    _intakePatterns[3]['controller'] = _feedController;
    _intakePatterns[4]['controller'] = _medicationController;
    _intakePatterns[5]['controller'] = _urineController;
    
    _voiceSteps = _intakePatterns.map((v) => v['label'] as String).toList();
    
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
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_showVoiceOverlay && !_isProcessingVoice && !_isVoiceInputComplete && mounted) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_showVoiceOverlay && !_isVoiceInputComplete && mounted) {
                  _startVoiceListening();
                }
              });
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
          _retrySpeechListening();
        },
      );
    } catch (e) {
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
            _processVoiceInputForCurrentStep(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      _retrySpeechListening();
    }
  }

  void _processVoiceInputForCurrentStep(String text) {
    if (text.isEmpty || _isProcessingVoice) return;

    setState(() {
      _isProcessingVoice = true;
      _isListening = false;
    });
    
    if (_isSkipCommand(text)) {
      _skipCurrentField();
      return;
    }
    
    final value = _extractNumericValue(text);
    
    if (value != null) {
      _voiceCollectedValues[_currentVoiceStep] = value;
      _updateFieldWithValue(_currentVoiceStep, value);
      _showVoiceStepSuccess(value);
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _showVoiceOverlay) {
          _moveToNextVoiceStep();
        }
      });
    } else {
      setState(() {
        _voiceInstruction = 'Could not understand. Please say ${_voiceSteps[_currentVoiceStep]} value or say "Skip". Example: "100"';
        _recognizedText = '';
        _isProcessingVoice = false;
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    }
  }

  bool _isSkipCommand(String text) {
    final skipWords = ['skip', 'next', 'no', 'not needed', 'not required', 'pass'];
    final cleanText = text.toLowerCase().trim();
    return skipWords.contains(cleanText);
  }

  void _skipCurrentField() {
    _showSkipSuccess();
    
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
      text = text.toLowerCase();
      
      final replacements = {
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
      };
      
      for (final entry in replacements.entries) {
        text = text.replaceAll(entry.key, entry.value);
      }
      
      text = text.replaceAll(RegExp(r'[^\d]'), '');
      
      if (text.isNotEmpty) {
        return text;
      }
    } catch (e) {
      debugPrint('Error extracting numeric value: $e');
    }
    
    return null;
  }

  void _updateFieldWithValue(int stepIndex, String value) {
    final controller = _intakePatterns[stepIndex]['controller'] as TextEditingController;
    
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
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _showVoiceOverlay) {
          _startVoiceListening();
        }
      });
    } else {
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
      
      _voiceCollectedValues.remove(_currentVoiceStep + 1);
      
      final controller = _intakePatterns[_currentVoiceStep + 1]['controller'] as TextEditingController;
      if (mounted) {
        setState(() {
          controller.text = '';
        });
      }
      
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
              fontSize: 16,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully recorded ${_voiceCollectedValues.length} intake values:',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 8),
                ..._voiceCollectedValues.entries.map((entry) {
                  final fieldName = _voiceSteps[entry.key];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$fieldName: ${entry.value}',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  'Tap "Edit Values" to edit manually or "OK" to continue.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _hideVoiceOverlay();
              },
              child: Text('Edit Values', style: GoogleFonts.poppins(color: darkBlue, fontSize: 13)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _hideVoiceOverlay();
              },
              child: Text('OK', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSaveAssessment() async {
    setState(() {
      _errorMessage = null;
    });

    if (_dateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a date';
      });
      return;
    }

    bool allEmpty = _fluidController.text.isEmpty &&
        _tpnController.text.isEmpty &&
        _bloodFilterController.text.isEmpty &&
        _feedController.text.isEmpty &&
        _medicationController.text.isEmpty &&
        _urineController.text.isEmpty;

    if (allEmpty) {
      setState(() {
        _errorMessage = 'Please enter at least one intake value';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intake Assessment saved successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving assessment: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

Widget _buildVoiceOverlay() {
  return Positioned.fill(
    child: Container(
      color: const Color(0xCC000000), // Slightly darker background
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // Slightly smaller width
          constraints: const BoxConstraints(
            maxHeight: 500, // Fixed maximum height for consistency
            minHeight: 420,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Input',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Step ${_currentVoiceStep + 1} of ${_voiceSteps.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: _hideVoiceOverlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: (_currentVoiceStep + 1) / _voiceSteps.length,
                      backgroundColor: Colors.grey[200],
                      color: Colors.blue,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${((_currentVoiceStep + 1) / _voiceSteps.length * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Current field name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _voiceSteps[_currentVoiceStep],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A237E),
                  ),
                ),
              ),
              
              // Voice status/instruction
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _voiceInstruction,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _voiceInstruction.contains('Listening')
                        ? Colors.green
                        : _voiceInstruction.contains('Could not understand')
                            ? Colors.red
                            : Colors.grey[700],
                  ),
                ),
              ),
              
              // Mic animation/icon
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 80 : 60,
                  height: _isListening ? 80 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? const Color(0xFFE3F2FD) : Colors.grey[100],
                    border: Border.all(
                      color: _isListening ? Colors.blue : Colors.grey[300] ?? Colors.grey,
                      width: _isListening ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: _isProcessingVoice
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : Icon(
                            Icons.mic,
                            size: _isListening ? 32 : 28,
                            color: _isListening ? Colors.blue : Colors.grey[600],
                          ),
                  ),
                ),
              ),
              
              // Recognized text
              if (_recognizedText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                    ),
                    child: Text(
                      _recognizedText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              
              // Current value if captured
              if (_voiceCollectedValues.containsKey(_currentVoiceStep))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Value: ${_voiceCollectedValues[_currentVoiceStep]}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Example hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      'Example:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getExampleHint(_currentVoiceStep),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Or say "Skip" to skip this field',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Control buttons - FIXED to avoid overflow
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _currentVoiceStep > 0 && !_isProcessingVoice ? _moveToPreviousVoiceStep : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color: _currentVoiceStep > 0 && !_isProcessingVoice 
                                    ? const Color(0xFF1A237E) 
                                    : Colors.grey[300] ?? Colors.grey,
                              ),
                            ),
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _currentVoiceStep > 0 && !_isProcessingVoice 
                                    ? const Color(0xFF1A237E) 
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessingVoice ? null : () {
                              _skipCurrentField();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.orange),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Next/Finish button
                    SizedBox(
                      width: double.infinity,
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
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                                    ? (_currentVoiceStep < _voiceSteps.length - 1 ? 'Next Field' : 'Finish & Save')
                                    : 'Speak Now',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
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
      case 0: return '"100"';
      case 1: return '"50"';
      case 2: return '"200"';
      case 3: return '"150"';
      case 4: return '"30"';
      case 5: return '"300"';
      default: return 'Say the number clearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[100] ?? Colors.grey),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildSectionHeader("Date & Time"),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
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
                              _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: bgGrey,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: darkBlue, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _dateController.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: darkBlue, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$_selectedHH:$_selectedMM',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
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

              const SizedBox(height: 16),

              _buildSectionHeader("Vitals Measurements"),
              
              GestureDetector(
                onTap: _startVoiceInput,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF64B5F6), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2264B5F6),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3D1A237E),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step-by-Step Voice Input',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Speak each value one by one. Say "Skip" to skip a field.',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF3949AB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1A237E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.chevron_right, color: darkBlue, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _fluidController,
                          label: "Fluid",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.water_drop,
                          focusNode: _focusNodes[0],
                          fieldIndex: 0,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _tpnController,
                          label: "TPN",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.medical_services,
                          focusNode: _focusNodes[1],
                          fieldIndex: 1,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _bloodFilterController,
                          label: "Blood/PVE 40 H Filter",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.bloodtype,
                          focusNode: _focusNodes[2],
                          fieldIndex: 2,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _feedController,
                          label: "Feed",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.restaurant,
                          focusNode: _focusNodes[3],
                          fieldIndex: 3,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _medicationController,
                          label: "Medication",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.medication,
                          focusNode: _focusNodes[4],
                          fieldIndex: 4,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildIntakeInput(
                          controller: _urineController,
                          label: "Urine",
                          hint: "0",
                          range: "0-0",
                          icon: Icons.wc,
                          focusNode: _focusNodes[5],
                          fieldIndex: 5,
                          currentFieldIndex: _currentFieldIndex,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 60),
            ],
          ),
        ),

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

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -3))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSaveAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text("Save Assessment", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        title, 
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])
      ),
    );
  }

  Widget _buildIntakeInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String range,
    required IconData icon,
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
            Expanded(
              child: Text(
                label, 
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])
              ),
            ),
            if (fieldIndex != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isCurrentField ? darkBlue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${fieldIndex + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: isCurrentField ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "Range: $range",
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: bgGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrentField ? darkBlue : Colors.grey[200] ?? Colors.grey,
              width: isCurrentField ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: darkBlue, size: 16),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}