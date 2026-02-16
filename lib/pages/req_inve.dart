import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/services/notification_service.dart';
import '../services/investigation_service.dart';

class ReqInvestigationPage extends StatefulWidget {
  final String patientName;
  final Patient patient;
  const ReqInvestigationPage({
    super.key,
    required this.patient,
    required this.patientName,
  });

  @override
  State<ReqInvestigationPage> createState() => _ReqInvestigationPageState();
}

class _ReqInvestigationPageState extends State<ReqInvestigationPage> {
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _parameterController = TextEditingController();
  final TextEditingController _indicationsController = TextEditingController();
  final TextEditingController _totalController = TextEditingController(text: "0");
  final TextEditingController _consultantNameController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();

  String? _selectedLocation;
  String? _selectedJobTitle;
  Map<String, dynamic>? _selectedInvestigationType;
  String? _selectedPackage;
  bool _isUrgent = false;

  final List<Map<String, dynamic>> _investigationItems = [];
  final List<String> locations = ["AH (Nagpur)", "Other Location"];
  final List<String> jobTitles = ["Pathlab", "Radiology", "Cardiology", "Other"];
  List<String> templateList = [];
  List<Map<String, dynamic>> investigationTypes = [];
  List<dynamic> parameterList = [];

  String? _tpId;
  String? _wardId;
  Map<String, dynamic>? _patientIpdData;
  Map<String, bool> selectedParameters = {};
  bool _showParameterDropdown = false;
  bool _isLoadingAmount = false;
  final bool _isLoadingJobTitles = false; 
  bool _isLoadingTemplates = false;
  bool _isLoadingParameters = false;
  bool _isLoadingPatientIpdData = false;
  bool _isSubmitting = false;
  bool _isLoadingInvestigationTypes = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListeningForPackage = false;
  bool _isListeningForInvestigationType = false;
  String _recognizedText = '';
  Timer? _speechTimeoutTimer;


  final List<Map<String, dynamic>> _recognizedTests = [];
  bool _isProcessingMultipleTests = false;
  bool _isSpeechInitialized = false;

  final Map<String, int> _jobTitleToTypeId = {
    'Pathlab': 5,      
    'Radiology': 7,     
    'Cardiology': 20,   
    'Other': 1,         
  };

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _selectedLocation = locations.isNotEmpty ? locations[0] : "AH (Nagpur)";
    _loadInitialData();
    _loadTemplates();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              if (status == stt.SpeechToText.notListeningStatus) {
                _isListeningForPackage = false;
                _isListeningForInvestigationType = false;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Speech initialization error: $error');
          if (mounted) {
            setState(() {
              _speechAvailable = false;
              _isListeningForPackage = false;
              _isListeningForInvestigationType = false;
            });
            _showSnackBar('Speech recognition error: $error', Colors.orange,
            duration: 2
            );
          }
        },
      );
      _isSpeechInitialized = true;
      debugPrint('Speech initialized: $_speechAvailable');
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
      _speechAvailable = false;
      _isSpeechInitialized = false;
    }
  }

  Future<void> _startVoiceSearchForPackage() async {
    if (_isListeningForPackage) {
      await _stopListening();
      return;
    }

    if (!_isSpeechInitialized) {
      await _initSpeech();
      if (!_speechAvailable) {
        _showSnackBar('Speech recognition is not available on this device', Colors.orange, duration: 2);
        return;
      }
    }

    bool hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      bool permissionGranted = await _speech.initialize();
      if (!permissionGranted) {
        _showSnackBar('Microphone permission is required for voice input', Colors.orange, duration:1);
        return;
      }
    }

    setState(() {
      _isListeningForPackage = true;
      _isListeningForInvestigationType = false;
      _recognizedText = '';
    });

    try {
      final options = stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          
          _speechTimeoutTimer?.cancel();
          _speechTimeoutTimer = Timer(const Duration(seconds: 2), () {
            if (_isListeningForPackage && _recognizedText.isNotEmpty) {
              _processPackageVoiceCommand(_recognizedText);
            }
          });

          if (result.finalResult) {
            _processPackageVoiceCommand(_recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
        listenOptions: options,
      );
      
      _showSnackBar('Listening for package name... Speak now', Colors.blue,duration:1);
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      if (mounted) {
        setState(() {
          _isListeningForPackage = false;
        });
        _showSnackBar('Failed to start listening: $e', Colors.red,duration:1);
      }
    }
  }

  Future<void> _startVoiceSearchForInvestigationType() async {
    if (_isListeningForInvestigationType) {
      await _stopListening();
      return;
    }

    if (!_isSpeechInitialized) {
      await _initSpeech();
      if (!_speechAvailable) {
        _showSnackBar('Speech recognition is not available on this device', Colors.orange,duration: 1);
        return;
      }
    }

    if (_selectedJobTitle == null) {
      _showSnackBar('Please select a job title first', Colors.orange,duration: 2);
      return;
    }

    if (investigationTypes.isEmpty) {
      _showSnackBar('No investigation types loaded. Please wait or select job title again.', Colors.orange, duration: 1);
      return;
    }

    bool hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      bool permissionGranted = await _speech.initialize();
      if (!permissionGranted) {
        _showSnackBar('Microphone permission is required for voice input', Colors.orange, duration: 1);
        return;
      }
    }

    setState(() {
      _isListeningForInvestigationType = true;
      _isListeningForPackage = false;
      _recognizedText = '';
    });

    try {
      final options = stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          
          setState(() {
            _recognizedText = result.recognizedWords;
          });

          _speechTimeoutTimer?.cancel();
          _speechTimeoutTimer = Timer(const Duration(milliseconds: 1500), () {
            if (_isListeningForInvestigationType && _recognizedText.isNotEmpty) {
              _processMultipleInvestigationTypesVoiceCommand(_recognizedText);
            }
          });

      
          if (result.finalResult) {
            _speechTimeoutTimer?.cancel();
            _processMultipleInvestigationTypesVoiceCommand(_recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        localeId: 'en_IN',
        listenOptions: options,
      );

      _showSnackBar('Listening for multiple tests... Say test names like "CBC, KFT, Urine"', Colors.blue, duration: 2);
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      if (mounted) {
        setState(() {
          _isListeningForInvestigationType = false;
        });
        _showSnackBar('Failed to start listening: $e', Colors.red, duration: 1);
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
    _speechTimeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isListeningForPackage = false;
        _isListeningForInvestigationType = false;
      });
    }
  }

  void _processPackageVoiceCommand(String text) {
    if (text.isEmpty) {
      _showSnackBar('No speech detected. Please try again.', Colors.orange, duration: 1);
      return;
    }

    _stopListening();

    String cleanText = text.toLowerCase();
    
    cleanText = cleanText
        .replaceAll('search for', '')
        .replaceAll('find', '')
        .replaceAll('package', '')
        .replaceAll('test', '')
        .replaceAll('tests', '')
        .replaceAll('investigation', '')
        .trim();

    if (cleanText.isEmpty) {
      _showSnackBar('Could not recognize package name. Please try again.', Colors.orange, duration: 1);
      return;
    }
    
    setState(() {
      _packageController.text = cleanText;
      _selectedPackage = cleanText;
    });
    
    _showSnackBar('Package set to: $cleanText', Colors.green, duration: 1);
  }

  Future<void> _processMultipleInvestigationTypesVoiceCommand(String text) async {
    if (text.isEmpty) {
      _showSnackBar('No speech detected. Please try again.', Colors.orange, duration: 1);
      return;
    }

    await _stopListening();
    
    if (!mounted) return;
    
    setState(() => _isProcessingMultipleTests = true);

    debugPrint('Original recognized text: "$text"');

    String cleanText = text.trim();
    cleanText = cleanText
        .replaceAll(RegExp(r'^(select|choose|add|please)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r"\s+(that'?s it|done|thank you|thanks)$", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+plus\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+with\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+&\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'[^\w\s,]', caseSensitive: false), ' ') 
        .replaceAll(RegExp(r'\s+'), ' ') 
        .trim();

    debugPrint('Cleaned text: "$cleanText"');


    List<String> spokenTests = [];
    
    if (cleanText.contains(',')) {
      spokenTests = cleanText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length > 1)
          .toList();
    } else {
      List<String> words = cleanText.split(' ').where((w) => w.length > 1).toList();
      if (words.length >= 2) {
        List<String> combinedTests = [];
        int i = 0;
        while (i < words.length) {
          if (i < words.length - 1) {
            String twoWord = '${words[i]} ${words[i+1]}';
            bool foundTwoWord = investigationTypes.any((type) {
              final typeName = (type['name'] ?? '').toString().toLowerCase();
              return typeName.contains(twoWord) || twoWord.contains(typeName.replaceAll(' ', ''));
            });
            
            if (foundTwoWord) {
              combinedTests.add(twoWord);
              i += 2;
              continue;
            }
          }
          combinedTests.add(words[i]);
          i++;
        }
        spokenTests = combinedTests;
      } else {
        spokenTests = words;
      }
    }

    spokenTests = spokenTests.toSet().where((test) => test.isNotEmpty).toList();

    debugPrint('Processed test names: $spokenTests');
    debugPrint('Available investigation types: ${investigationTypes.length}');

    if (spokenTests.isEmpty) {
      setState(() => _isProcessingMultipleTests = false);
      _showSnackBar('Could not recognize test names. Please try again or type manually.', Colors.orange, duration: 2);
      return;
    }

    List<Map<String, dynamic>> matchedTests = [];
    List<String> unmatchedTests = [];

    for (String spokenTest in spokenTests) {
      String normalizedSpoken = spokenTest.toLowerCase().trim();
      bool found = false;
      
      for (var type in investigationTypes) {
        final typeName = (type['name'] ?? '').toString().toLowerCase().trim();
        
   
        if (typeName == normalizedSpoken || 
            typeName.contains(normalizedSpoken) || 
            normalizedSpoken.contains(typeName)) {
          if (!matchedTests.any((t) => t['id'] == type['id'])) {
            matchedTests.add(type);
            found = true;
            debugPrint('✅ Matched "$spokenTest" to "${type['name']}"');
            break;
          }
        }
      }
      
      if (!found) {
        bool foundInSecondPass = false;
        for (var type in investigationTypes) {
          final typeName = (type['name'] ?? '').toString().toLowerCase();
          if (_isCommonAbbreviation(normalizedSpoken, typeName)) {
            if (!matchedTests.any((t) => t['id'] == type['id'])) {
              matchedTests.add(type);
              foundInSecondPass = true;
              debugPrint('✅ Matched via abbreviation "$spokenTest" to "${type['name']}"');
              break;
            }
          }
        }
        
        if (!foundInSecondPass) {
          unmatchedTests.add(spokenTest);
          debugPrint('❌ Unmatched test: "$spokenTest"');
        }
      }
    }

    debugPrint('Matched tests: ${matchedTests.length}');
    debugPrint('Unmatched tests: $unmatchedTests');

    if (!mounted) return;
    
    setState(() {
      _isProcessingMultipleTests = false;
    });

    if (matchedTests.isEmpty) {
      _showSnackBar('No matching tests found for: ${spokenTests.join(", ")}', Colors.orange, duration: 3);
      return;
    }
    
    _showMultiTestConfirmationDialog(matchedTests, unmatchedTests);
  }

  bool _isCommonAbbreviation(String spoken, String fullName) {
    Map<String, List<String>> commonAbbreviations = {
      'cbc': ['complete blood count', 'blood count'],
      'kft': ['kidney function test', 'renal function'],
      'lft': ['liver function test', 'hepatic function'],
      'rft': ['renal function test'],
      'tft': ['thyroid function test'],
      'ecg': ['electrocardiogram', 'ekg'],
      'ekg': ['electrocardiogram', 'ecg'],
      'xray': ['x-ray', 'radiograph'],
      'x ray': ['x-ray', 'radiograph'],
      'ct': ['computed tomography', 'cat scan'],
      'ct scan': ['computed tomography'],
      'mri': ['magnetic resonance imaging'],
      'urine': ['urinalysis', 'urine analysis', 'urine r/e'],
      'ua': ['urinalysis', 'urine analysis'],
      'stool': ['stool analysis', 'stool r/e'],
      'blood': ['blood test'],
      'sugar': ['blood sugar', 'glucose'],
      'lipid': ['lipid profile'],
    };

    String normalizedSpoken = spoken.replaceAll(' ', '').toLowerCase();
    String normalizedFull = fullName.replaceAll(' ', '').toLowerCase();

    if (normalizedFull.contains(normalizedSpoken) && normalizedSpoken.length > 2) {
      return true;
    }

    for (var entry in commonAbbreviations.entries) {
      if (normalizedSpoken.contains(entry.key) || entry.key.contains(normalizedSpoken)) {
        for (var fullForm in entry.value) {
          String normalizedForm = fullForm.replaceAll(' ', '').toLowerCase();
          if (normalizedFull.contains(normalizedForm)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  void _showMultiTestConfirmationDialog(
    List<Map<String, dynamic>> matchedTests,
    List<String> unmatchedTests,
  ) {
    Map<int, Map<String, dynamic>> testDetails = {};
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            for (var test in matchedTests) {
              if (!testDetails.containsKey(test['id'])) {
                testDetails[test['id']] = {
                  'name': test['name'],
                  'charge': test['charge'] ?? '0',
                  'code': test['code'] ?? test['searchCode'] ?? '',
                  'parameters': '',
                  'isLoading': true,
                };
              }
            }
            
            _loadTestDetailsForDialog(matchedTests, testDetails, setDialogState);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirm Multiple Tests',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${matchedTests.length} test(s):',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    ...matchedTests.asMap().entries.map((entry) {
                      int index = entry.key;
                      var test = entry.value;
                      var details = testDetails[test['id']]!;
                      bool isLoading = details['isLoading'] == true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLoading ? Colors.grey[100] : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLoading ? Colors.grey[300]! : Colors.green.shade200,
                          ),
                        ),
                        child: isLoading
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Loading ${test['name'] ?? 'test'} details...',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  radius: 16,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        test['name'] ?? '',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (details['charge'] != null && details['charge'] != '0')
                                        Text(
                                          '₹${details['charge']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (details['code'] != null && details['code'].toString().isNotEmpty)
                                        Text(
                                          'Code: ${details['code']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setDialogState(() {
                                      matchedTests.removeAt(index);
                                      testDetails.remove(test['id']);
                                    });
                                    if (matchedTests.isEmpty) {
                                      Navigator.pop(context);
                                      _showSnackBar('All tests removed', Colors.orange, duration: 2);
                                    }
                                  },
                                ),
                              ],
                            ),
                      );
                    }).toList(),
                    
                    if (unmatchedTests.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Could not find:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ...unmatchedTests.map((test) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                test,
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap "Add All" to add these tests to your request',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: matchedTests.isEmpty
                      ? null
                      : () async {
                          bool allLoaded = testDetails.values.every((detail) => detail['isLoading'] == false);
                          
                          if (!allLoaded) {
                            _showSnackBar('Please wait while we load all test details...', Colors.blue, duration: 2);
                            return;
                          }
                          
                          Navigator.pop(context);
                          await _addMultipleTests(matchedTests, testDetails);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Add All (${matchedTests.length})',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadTestDetailsForDialog(
    List<Map<String, dynamic>> tests,
    Map<int, Map<String, dynamic>> testDetails,
    StateSetter setDialogState,
  ) async {
    for (var test in tests) {
      try {
        final details = await _getTestDetails(test);
        
        if (mounted) {
          setDialogState(() {
            testDetails[test['id']] = {
              'name': test['name'],
              'charge': details['charge'] ?? test['charge'] ?? '0',
              'code': details['code'] ?? test['code'] ?? test['searchCode'] ?? '',
              'parameters': details['parameters'] ?? '',
              'isLoading': false,
            };
          });
        }
      } catch (e) {
        debugPrint('Error loading details for ${test['name']}: $e');
        if (mounted) {
          setDialogState(() {
            testDetails[test['id']] = {
              'name': test['name'],
              'charge': test['charge'] ?? '0',
              'code': test['code'] ?? test['searchCode'] ?? '',
              'parameters': '',
              'isLoading': false,
            };
          });
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<Map<String, dynamic>> _getTestDetails(Map<String, dynamic> test) async {
    try {
      final int testTypeId = test['id'] ?? 0;
      final String testTypeName = test['name'] ?? '';
      final String fallbackCharge = test['charge']?.toString() ?? '0';

    
      if (_tpId != null && _wardId != null && testTypeId != 0) {
        final chargeResponse = await InvestigationService.getCharge(
          tpId: _tpId!,
          investigationId: testTypeId,
          wardId: _wardId!,
          name: testTypeName,
        );

        dynamic amount = chargeResponse['data'] ??
            chargeResponse['charge'] ??
            chargeResponse['amount'] ??
            chargeResponse['rate'];
        
        if (amount == null || amount.toString() == '0') {
          amount = fallbackCharge;
        }

        return {
          'name': test['name'],
          'charge': amount.toString(),
          'code': test['code'] ?? test['searchCode'] ?? testTypeId.toString(),
          'parameters': '',
        };
      } else {
        final String gender = widget.patient.gender;
        final params = await InvestigationService.fetchParameterList(
          investigationTypeId: testTypeId,
          gender: gender,
        );

        String parameterString = '';
        if (params.isNotEmpty) {
          parameterString = params
              .map((p) => (p['parameterName'] ?? p['name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .join(', ');
        }

        return {
          'name': test['name'],
          'charge': fallbackCharge,
          'code': test['code'] ?? test['searchCode'] ?? testTypeId.toString(),
          'parameters': parameterString,
        };
      }
    } catch (e) {
      debugPrint('Error getting test details: $e');
      return {
        'name': test['name'],
        'charge': test['charge']?.toString() ?? '0',
        'code': test['code'] ?? test['searchCode'] ?? test['id']?.toString() ?? '',
        'parameters': '',
      };
    }
  }

  Future<void> _addMultipleTests(
    List<Map<String, dynamic>> tests,
    Map<int, Map<String, dynamic>> testDetails,
  ) async {
    if (!mounted) return;
    
    setState(() => _isProcessingMultipleTests = true);

    int addedCount = 0;
    int failedCount = 0;

    for (var test in tests) {
      try {
        final details = testDetails[test['id']] ?? {};
        
        String packageName = _packageController.text.trim();
        if (packageName.isEmpty && _selectedPackage != null) {
          packageName = _selectedPackage!;
        }

        String parameterString = '';
        try {
          final int testTypeId = test['id'] ?? 0;
          final String gender = widget.patient.gender;
          
          final params = await InvestigationService.fetchParameterList(
            investigationTypeId: testTypeId,
            gender: gender,
          );
          
          if (params.isNotEmpty) {
            parameterString = params
                .map((p) => (p['parameterName'] ?? p['name'] ?? '').toString())
                .where((name) => name.isNotEmpty)
                .join(', ');
          }
        } catch (e) {
          debugPrint('Error fetching parameters for ${test['name']}: $e');
          parameterString = details['parameters']?.toString() ?? '';
        }

     
        Map<String, dynamic> testItem = {
          'package': packageName,
          'type': test['name'] ?? '',
          'typeId': test['id'] ?? 0,
          'gender': test['gender'] ?? widget.patient.gender,
          'searchCode': details['code']?.toString() ?? test['code']?.toString() ?? test['searchCode']?.toString() ?? '',
          'amount': details['charge']?.toString() ?? '0',
          'parameter': parameterString,
          'indications': _indicationsController.text.trim(),
          'urgent': _isUrgent,
        };


        setState(() {
          _investigationItems.add(testItem);
        });
        
        addedCount++;
        
      } catch (e) {
        debugPrint('Error adding test ${test['name']}: $e');
        failedCount++;
      }
    
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() {
        _isProcessingMultipleTests = false;
      });
    }

    _updateTotal();
    _clearForm();

 
    String message = '';
    Color backgroundColor = Colors.green;

    if (addedCount > 0 && failedCount == 0) {
      message = '$addedCount test(s) added successfully!';
    } else if (addedCount > 0 && failedCount > 0) {
      message = '$addedCount test(s) added, $failedCount failed';
      backgroundColor = Colors.orange;
    } else {
      message = 'Failed to add tests';
      backgroundColor = Colors.red;
    }

    _showSnackBar(message, backgroundColor);
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPatientIpdData = true;
    });

    try {
      final ipdData = await InvestigationService.fetchPatientIpdDetails(
        patientId: widget.patient.patientid,
      );

      if (ipdData != null && ipdData.isNotEmpty) {
        String? extractedTpId = ipdData['tpId']?.toString() ??
            ipdData['treatmentPlanId']?.toString() ??
            ipdData['tpid']?.toString();
        String? extractedWardId = ipdData['wardId']?.toString() ??
            ipdData['wardid']?.toString() ??
            ipdData['ward_id']?.toString();

        if (extractedTpId == 'null') extractedTpId = null;
        if (extractedWardId == 'null') extractedWardId = null;

        if (mounted) {
          setState(() {
            _tpId = extractedTpId;
            _wardId = extractedWardId;
            _isLoadingPatientIpdData = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingPatientIpdData = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoadingPatientIpdData = false;
        });
      }
    }
  }

  Future<void> _loadTemplates() async {
    if (!mounted) return;
    
    setState(() => _isLoadingTemplates = true);
    try {
      final templates = await InvestigationService.fetchInvestigationTemplates();
      if (mounted) {
        setState(() {
          templateList = templates;
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  Future<void> _loadInvestigationTypesForJobTitle(String jobTitle) async {
    if (jobTitle.isEmpty) return;
    
    if (!mounted) return;
    
    setState(() => _isLoadingInvestigationTypes = true);
    
    try {
      int typeId = _jobTitleToTypeId[jobTitle] ?? 1; 
      
      debugPrint('🔹 Loading investigation types for job title: $jobTitle (Type ID: $typeId)');
      
      final types = await InvestigationService.fetchInvestigationTypes(typeId: typeId);
      
      if (mounted) {
        setState(() {
          investigationTypes = types;
          _isLoadingInvestigationTypes = false;
          _selectedInvestigationType = null;
          _amountController.clear();
          _searchCodeController.clear();
          parameterList = [];
          selectedParameters = {};
          _parameterController.clear();
          _showParameterDropdown = false;
        });
        debugPrint('✅ Loaded ${investigationTypes.length} investigation types');
      }
    } catch (e) {
      debugPrint('Error loading investigation types: $e');
      if (mounted) {
        setState(() {
          investigationTypes = [];
          _isLoadingInvestigationTypes = false;
          _selectedInvestigationType = null;
        });
       
        _showSnackBar('Failed to load investigations for $jobTitle', Colors.red, duration: 2);
      }
    }
  }

  Future<void> _onInvestigationTypeSelected(Map<String, dynamic> investigationType) async {
    if (!mounted) return;
    
    setState(() {
      _selectedInvestigationType = investigationType;
    });
    
    try {
      await Future.wait([
        _fetchChargeForInvestigation(investigationType['name']),
        _fetchParametersForInvestigationType(),
      ]);
    } catch (e) {
      debugPrint('Error in onInvestigationTypeSelected: $e');
    }
  }

  Future<void> _fetchParametersForInvestigationType() async {
    if (_selectedInvestigationType == null) return;
    
    if (!mounted) return;
    
    setState(() => _isLoadingParameters = true);

    try {
      final int typeId = _selectedInvestigationType!['id'] ?? 0;
      final String gender = widget.patient.gender;

      final params = await InvestigationService.fetchParameterList(
        investigationTypeId: typeId,
        gender: gender,
      );

      if (mounted) {
        setState(() {
          parameterList = params;
          selectedParameters = {
            for (var param in params)
              (param['parameterName'] ?? param['name'] ?? '').toString(): true
          };
          _parameterController.text = _getSelectedParametersString();
          _isLoadingParameters = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching parameters: $e');
      if (mounted) {
        setState(() {
          parameterList = [];
          selectedParameters = {};
          _isLoadingParameters = false;
        });
      }
    }
  }

  Future<void> _fetchChargeForInvestigation(String investigationType) async {
    if (_isLoadingPatientIpdData) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (!mounted) return;
    
    setState(() => _isLoadingAmount = true);

    try {
      final int testTypeId = _selectedInvestigationType?['id'] ?? 0;
      final String testTypeName = investigationType.isNotEmpty
          ? investigationType
          : (_selectedInvestigationType?['name'] ?? '');
      final String fallbackCharge =
          _selectedInvestigationType?['charge']?.toString() ?? '0';

      if (_tpId == null || _wardId == null || testTypeId == 0) {
        if (mounted) {
          setState(() {
            _amountController.text = fallbackCharge;
            _isLoadingAmount = false;
          });
        }
        return;
      }

      final chargeResponse = await InvestigationService.getCharge(
        tpId: _tpId!,
        investigationId: testTypeId,
        wardId: _wardId!,
        name: testTypeName,
      );

      if (mounted) {
        setState(() {
          dynamic amount = chargeResponse['data'] ??
              chargeResponse['charge'] ??
              chargeResponse['amount'] ??
              chargeResponse['rate'];
          if (amount == null || amount.toString() == '0') amount = fallbackCharge;
          _amountController.text = amount.toString();
          _isLoadingAmount = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching charge: $e');
      if (mounted) {
        setState(() {
          final fallbackCharge = _selectedInvestigationType?['charge']?.toString() ?? '0';
          _amountController.text = fallbackCharge;
          _isLoadingAmount = false;
        });
      }
    }
  }

  String _getSelectedParametersString() {
    final selected = selectedParameters.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    return selected.join(', ');
  }

  void _addItem() {
    if (_selectedInvestigationType == null) {
      _showSnackBar('Please select an Investigation Type.', Colors.red, duration: 2);
      return;
    }

    String packageName = _packageController.text.trim();
    if (packageName.isEmpty && _selectedPackage != null) {
      packageName = _selectedPackage!;
    }

    setState(() {
      _investigationItems.add({
        'package': packageName,
        'type': _selectedInvestigationType!['name'] ?? '',
        'typeId': _selectedInvestigationType!['id'] ?? 0,
        'gender': _selectedInvestigationType!['gender'] ?? '',
        'searchCode': _searchCodeController.text.trim(),
        'amount': _amountController.text.trim().isEmpty ? '0' : _amountController.text.trim(),
        'parameter': _getSelectedParametersString(),
        'indications': _indicationsController.text.trim(),
        'urgent': _isUrgent,
      });

      _clearForm();
      _updateTotal();
    });

    _showSnackBar('Item added successfully!', Colors.green, duration: 2);
  }

  void _clearForm() {
    _packageController.clear();
    _selectedPackage = null;
    _selectedInvestigationType = null;
    _searchCodeController.clear();
    _amountController.clear();
    _parameterController.clear();
    _indicationsController.clear();
    _isUrgent = false;
    parameterList = [];
    selectedParameters = {};
    _showParameterDropdown = false;
  }

  void _updateTotal() {
    double total = 0;
    for (var item in _investigationItems) {
      total += double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    }
    _totalController.text = total.toStringAsFixed(2);
  }

  void _suggestJobTitleFromTemplate(String template) {
    final lowerTemplate = template.toLowerCase();
    String? suggestedJobTitle;

    if (lowerTemplate.contains('path') || lowerTemplate.contains('lab') || lowerTemplate.contains('blood')) {
      suggestedJobTitle = "Pathlab";
    } else if (lowerTemplate.contains('radio') || lowerTemplate.contains('x-ray') || lowerTemplate.contains('scan')) {
      suggestedJobTitle = "Radiology";
    } else if (lowerTemplate.contains('cardio') || lowerTemplate.contains('heart') || lowerTemplate.contains('ecg')) {
      suggestedJobTitle = "Cardiology";
    }

    if (suggestedJobTitle != null && jobTitles.contains(suggestedJobTitle) && _selectedJobTitle != suggestedJobTitle) {
      setState(() {
        _selectedJobTitle = suggestedJobTitle;
      });
      
      _loadInvestigationTypesForJobTitle(suggestedJobTitle);
      
      _showSnackBar('Suggested Job Title: $suggestedJobTitle', Colors.teal, duration: 2);
    }
  }

  Future<void> _submitInvestigationRequest() async {
    if (_investigationItems.isEmpty) {
      _showSnackBar('Please add at least one investigation item.', Colors.red, duration: 2);
      return;
    }

    if (_selectedJobTitle == null || _selectedJobTitle!.isEmpty) {
      _showSnackBar('Please select a Job Title.', Colors.red, duration: 2);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await InvestigationService.saveInvestigationRequest(
        patientId: widget.patient.patientid,
        jobTitle: _selectedJobTitle!,
        location: _selectedLocation ?? "AH (Nagpur)",
        consultantName: _consultantNameController.text.trim(),
        testList: _investigationItems,
        investigations: _investigationItems,
        totalAmount: _totalController.text,
        isUrgent: _isUrgent,
        tpId: _tpId,
        wardId: _wardId,
      );

      final bool isSuccess = result['success'] == true;
      final String responseMessage = result['message']?.toString() ?? '';

      if (isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_investigation_save_time', DateTime.now().toIso8601String());
        await prefs.setBool('shouldRefreshNotifications', true);
        await NotificationRefreshService().markInvestigationSaved();
        
        String successMessage = responseMessage.isNotEmpty 
            ? responseMessage 
            : 'Investigation Request Submitted Successfully!';
        
        if (successMessage.endsWith('.')) {
          successMessage = successMessage.substring(0, successMessage.length - 1);
        }
        _showSnackBar('$successMessage. Notifications will refresh automatically.', Colors.green, duration: 2);
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          _investigationItems.clear();
          _updateTotal();
          Navigator.pop(context, true);
        }
      } else {
        String errorMessage = 'Failed to submit investigation request';
        if (responseMessage.isNotEmpty) {
          errorMessage = responseMessage;
        }
        
        final lowerMessage = responseMessage.toLowerCase();
        if (lowerMessage.contains('saved successfully') || 
            lowerMessage.contains('investigation request saved')) {
          debugPrint('✅ Investigation saved despite 400 status');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_investigation_save_time', DateTime.now().toIso8601String());
          await prefs.setBool('shouldRefreshNotifications', true);
          await NotificationRefreshService().markInvestigationSaved();
          
          String successMessage = responseMessage.isNotEmpty 
              ? responseMessage 
              : 'Investigation Request Submitted Successfully!';
          
          if (successMessage.endsWith('.')) {
            successMessage = successMessage.substring(0, successMessage.length - 1);
          }
          
          await Future.delayed(const Duration(milliseconds: 1500));
          
          if (mounted) {
            _investigationItems.clear();
            _updateTotal();
            Navigator.pop(context, true);
          }
        } else {
          _showSnackBar(errorMessage, Colors.orange, duration: 2);
        }
      }
    } catch (e) {
      debugPrint('Error submitting investigation: $e');
      _showSnackBar('Network error occurred while submitting', Colors.red, duration: 2);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 3), 
        Container(
          height: 44, 
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10), 
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onChanged: onChanged,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 16), 
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              isDense: true,
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11), 
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldContainer({required Widget child}) {
    return Container(
      height: 44, 
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _buildSelectableField({
    required String? value,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    String placeholder = "Select",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            onTap();
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: (value != null && value.isNotEmpty) ? const Color(0xFF1A237E) : Colors.grey[500], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (value != null && value.isNotEmpty) ? value : placeholder,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: (value != null && value.isNotEmpty) ? Colors.black87 : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchableSelectionSheet({
    required String title,
    required Future<List<String>> Function(String query) searchCallback,
    required Function(String) onSelected,
    bool showMic = false,
    Function()? onMicTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SearchableSheetContent(
        title: title, 
        searchCallback: searchCallback, 
        onSelected: onSelected,
        showMic: showMic,
        onMicTap: onMicTap,
        speech: _speech,
      ),
    );
  }

  void _showInvestigationTypeSheet(List<Map<String, dynamic>> types) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<Map<String, dynamic>> filteredList = List.from(types);
        bool isListening = false;
        String recognizedText = '';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  Text("Select Investigation Type", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: false,
                            controller: TextEditingController(text: recognizedText),
                            style: GoogleFonts.poppins(fontSize: 14),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value.isEmpty) {
                                  filteredList = List.from(types);
                                } else {
                                  filteredList = types.where((element) => (element['name'] ?? '').toString().toLowerCase().contains(value.toLowerCase())).toList();
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: isListening ? "Listening..." : "Search type...", 
                              border: InputBorder.none, 
                              prefixIcon: Icon(isListening ? Icons.mic : Icons.search, color: isListening ? Colors.blue : Colors.grey), 
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                            ),
                          ),
                        ),
                        IconButton(
                          icon: isListening
                            ? const Icon(Icons.stop, color: Colors.red)
                            : Icon(Icons.mic, color: Colors.blue[700]),
                          onPressed: () async {
                            if (isListening) {
                              _speech.stop();
                              setSheetState(() => isListening = false);
                            } else {
                              if (await _speech.hasPermission) {
                                setSheetState(() => isListening = true);
                                await _speech.listen(
                                  onResult: (result) {
                                    setSheetState(() {
                                      recognizedText = result.recognizedWords;
                                      filteredList = types.where((element) => (element['name'] ?? '').toString().toLowerCase().contains(recognizedText.toLowerCase())).toList();
                                    });
                                  },
                                  listenFor: const Duration(seconds: 10),
                                  localeId: 'en_US',
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(child: Text("No investigation types found", style: GoogleFonts.poppins(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: filteredList.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final type = filteredList[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[50],
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: const Icon(Icons.science, color: Colors.indigo, size: 20)
                                ),
                                title: Text(type['name'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: type['description']?.toString().isNotEmpty == true
                                    ? Text(type['description'].toString(), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)
                                    : null,
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _onInvestigationTypeSelected(type);
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
      },
    );
  }

  void _showInvestigationListPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10)
              )
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Request List", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("${_investigationItems.length} items", style: GoogleFonts.poppins(color: Colors.grey))
              ]
            ),
            if (_selectedJobTitle != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.work, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Category: $_selectedJobTitle', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))
                ],
              )
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _investigationItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("No investigations added", style: GoogleFonts.poppins(color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text("Add investigations using the form above", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]))
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _investigationItems.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _investigationItems[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!)
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                radius: 14,
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12
                                  )
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['type'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14
                                      )
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "₹${item['amount']} | ${item['urgent'] ? 'Urgent' : 'Normal'}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: item['urgent'] ? Colors.red : Colors.grey[600],
                                        fontWeight: item['urgent'] ? FontWeight.bold : FontWeight.normal
                                      )
                                    ),
                                    if (item['parameter']?.toString().isNotEmpty == true) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item['parameter'].toString(),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis
                                      )
                                    ]
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    _investigationItems.removeAt(index);
                                    _updateTotal();
                                  });
                                  Navigator.pop(context);
                                  _showInvestigationListPopup();
                                }
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

  void _showSnackBar(String message, Color backgroundColor, {int duration = 2}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: duration),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1A237E);
    const Color bgGrey = Color(0xFFF5F7FA);
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 5,
              left: 20,
              right: 20,
              bottom: 15
            ),
            decoration: const BoxDecoration(
              color: darkBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20)
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Investigation Request",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600
                            )
                          ),
                          Text(
                            widget.patientName,
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 12),
                          const SizedBox(width: 6),
                          Text(formattedDate, style: GoogleFonts.poppins(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "INVESTIGATION CATEGORY",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: darkBlue
                    )
                  ),
                  const SizedBox(height: 6),
                 SizedBox(
                    height: 32, 
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: jobTitles.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        bool isSelected = _selectedJobTitle == jobTitles[index];
                        return GestureDetector(
                          onTap: () {
                            final selectedTitle = jobTitles[index];
                            setState(() {
                              _selectedJobTitle = selectedTitle;
                            });
                            _loadInvestigationTypesForJobTitle(selectedTitle);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            decoration: BoxDecoration(
                              color: isSelected ? darkBlue : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? darkBlue : Colors.grey[300]!)
                            ),
                            child: Center(
                              child: Text(
                                jobTitles[index],
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.grey[700]
                                )
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SEARCH PACKAGE", 
                        style: GoogleFonts.poppins(
                          fontSize: 10, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.grey[600]
                        )
                      ),
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () {
                          _showSearchableSelectionSheet(
                            title: "Search Package",
                            searchCallback: (query) async {
                              if (query.isEmpty) return await InvestigationService.getCachedInvestigations();
                              return await InvestigationService.fetchInvestigations(query: query);
                            },
                            onSelected: (val) {
                              setState(() {
                                _packageController.text = val;
                                _selectedPackage = val;
                              });
                            },
                            showMic: true,
                            onMicTap: _startVoiceSearchForPackage,
                          );
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!)
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: (_packageController.text.isNotEmpty) ? darkBlue : Colors.grey[500], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isListeningForPackage ? "Listening... $_recognizedText" : (_packageController.text.isNotEmpty ? _packageController.text : "Search Package..."),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: (_isListeningForPackage || _packageController.text.isNotEmpty) ? Colors.black87 : Colors.grey[400]
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _isListeningForPackage
                                ? IconButton(
                                    icon: const Icon(Icons.stop, color: Colors.red, size: 18),
                                    onPressed: _stopListening,
                                  )
                                : IconButton(
                                    icon: Icon(Icons.mic, color: Colors.blue[700], size: 18),
                                    onPressed: _startVoiceSearchForPackage,
                                  ),
                              Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 16),
                            ],
                          ),
                        ),
                      ),
                      if (_isListeningForPackage)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Listening... Speak clearly',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12), 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0,5)
                        )
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Investigation Details",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: darkBlue
                          )
                        ),
                        const SizedBox(height: 10),
                        
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Investigation Type",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600]
                                    )
                                  ),
                                ),
                                if (_isLoadingInvestigationTypes)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                                if (_isProcessingMultipleTests)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: _selectedJobTitle == null
                                  ? () {
                                      _showSnackBar('Please select a Job Title first', Colors.red, duration: 2);
                                    }
                                  : () {
                                      if (investigationTypes.isNotEmpty && !_isLoadingInvestigationTypes) {
                                        _showInvestigationTypeSheet(investigationTypes);
                                      } else if (_isLoadingInvestigationTypes) {
                                        _showSnackBar('Loading investigation types...', Colors.blue, duration: 2);
                                      } else {
                                        _showSnackBar('No investigation types available for this category', Colors.orange, duration: 2);
                                      }
                                    },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!)
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.science,
                                      color: (_selectedInvestigationType != null) ? darkBlue : Colors.grey[500],
                                      size: 16
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isListeningForInvestigationType ? "Listening... $_recognizedText" : (_selectedInvestigationType?['name'] ?? 
                                          (_selectedJobTitle == null 
                                            ? 'Select Job Title First'
                                            : investigationTypes.isEmpty 
                                              ? 'No investigations available'
                                              : 'Select Investigation Type')),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: (_isListeningForInvestigationType || _selectedInvestigationType != null) 
                                            ? Colors.black87 
                                            : Colors.grey[400]
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _isListeningForInvestigationType
                                      ? IconButton(
                                          icon: const Icon(Icons.stop, color: Colors.red, size: 18),
                                          onPressed: _stopListening,
                                        )
                                      : IconButton(
                                          icon: Icon(Icons.mic, color: Colors.blue[700], size: 18),
                                          onPressed: _startVoiceSearchForInvestigationType,
                                        ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.grey[500],
                                      size: 16
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isListeningForInvestigationType)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Listening... Say test names like "CBC, KFT, Urine"',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedJobTitle != null && investigationTypes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${investigationTypes.length} investigation types available for $_selectedJobTitle',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])
                              )
                            ]
                          ],
                        ),
                        
                        const SizedBox(height: 8), 
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildModernInput(
                                    controller: _amountController,
                                    label: "Amount",
                                    icon: Icons.currency_rupee
                                  ),
                                  if (_isLoadingAmount)
                                    Positioned(
                                      right: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: darkBlue
                                          )
                                        )
                                      )
                                    )
                                ]
                              )
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildModernInput(
                                controller: _searchCodeController,
                                label: "Search Code",
                                icon: Icons.qr_code
                              )
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        GestureDetector(
                          onTap: () {
                            if (parameterList.isNotEmpty && !_isLoadingParameters) {
                              setState(() => _showParameterDropdown = !_showParameterDropdown);
                            }
                          },
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(
                                  "Parameters",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600]
                                  )
                                ),
                                const SizedBox(height: 3),
                                _buildFieldContainer(
                                  child: AbsorbPointer(
                                    child: TextField(
                                      controller: _parameterController,
                                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.list, color: Colors.grey[500], size: 16),
                                        suffixIcon: _isLoadingParameters 
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 10,
                                                height: 10,
                                                child: CircularProgressIndicator(strokeWidth: 2)
                                              )
                                            ) 
                                          : Icon(
                                              _showParameterDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                              color: Colors.grey,
                                              size: 18
                                            ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        hintText: "Parameters",
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                      ),
                                    ),
                                  ),
                                ),
                             ],
                          ),
                        ),
                        
                        if (_showParameterDropdown && parameterList.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!)
                            ),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(
                                    "Select All",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12
                                    )
                                  ),
                                  value: selectedParameters.values.every((v) => v),
                                  activeColor: darkBlue,
                                  onChanged: (val) {
                                    setState(() {
                                      selectedParameters = {
                                        for (var p in parameterList) 
                                          (p['parameterName'] ?? p['name']).toString(): val ?? true
                                      };
                                      _parameterController.text = _getSelectedParametersString();
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 120),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: parameterList.length,
                                    itemBuilder: (context, index) {
                                      final name = (parameterList[index]['parameterName'] ?? parameterList[index]['name']).toString();
                                      return CheckboxListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        title: Text(name, style: GoogleFonts.poppins(fontSize: 11)),
                                        value: selectedParameters[name] ?? false,
                                        activeColor: darkBlue,
                                        onChanged: (val) {
                                          setState(() {
                                            selectedParameters[name] = val ?? false;
                                            _parameterController.text = _getSelectedParametersString();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                )
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 3, 
                              child: _buildModernInput(
                                controller: _indicationsController,
                                label: "Indications",
                                icon: Icons.info_outline
                              )
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _isUrgent = !_isUrgent),
                                child: Container(
                                  height: 44, 
                                  decoration: BoxDecoration(
                                    color: _isUrgent ? Colors.red[50] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isUrgent ? Colors.red : Colors.grey[300]!
                                    )
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: _isUrgent ? Colors.red : Colors.grey
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Urgent",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: _isUrgent ? Colors.red : Colors.grey
                                        )
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  
                  _buildSelectableField(
                    value: _consultantNameController.text,
                    label: "CONSULTANT",
                    icon: Icons.person_outline,
                    placeholder: "Select Consultant",
                    onTap: () {
                      _showSearchableSelectionSheet(
                        title: "Select Consultant",
                        searchCallback: (query) async {
                          if (query.isEmpty) return [];
                          String branchId = (_selectedLocation ?? "AH (Nagpur)") == "AH (Nagpur)" ? "1" : "2";
                          final names = await InvestigationService.fetchPractitionersNames(
                            branchId: branchId,
                            specializationId: 0,
                            isVisitingConsultant: 0
                          );
                          return names.where((n) => n.toLowerCase().contains(query.toLowerCase())).toList();
                        },
                        onSelected: (val) {
                          setState(() => _consultantNameController.text = val);
                        }
                      );
                    }
                  ),

                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), 
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0,-5)
            )
          ]
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: darkBlue,
                    side: const BorderSide(color: darkBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text("Add +", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   onPressed: _investigationItems.isNotEmpty ? _showInvestigationListPopup : null,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey[100],
                     foregroundColor: Colors.black87,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     elevation: 0,
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.list, size: 18),
                       if(_investigationItems.isNotEmpty) ...[
                         const SizedBox(width: 4),
                         Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                           child: Text(
                             "${_investigationItems.length}",
                             style: const TextStyle(fontSize: 10, color: Colors.white, height: 1)
                           )
                         )
                       ]
                     ],
                   ),
                 ),
               ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitInvestigationRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    shadowColor: darkBlue.withOpacity(0.3),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : Text("Submit", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    _speechTimeoutTimer?.cancel();
    _speech.stop();
    super.dispose();
  }
}

class _SearchableSheetContent extends StatefulWidget {
  final String title;
  final Future<List<String>> Function(String query) searchCallback;
  final Function(String) onSelected;
  final bool showMic;
  final Function()? onMicTap;
  final stt.SpeechToText speech;

  const _SearchableSheetContent({
    required this.title,
    required this.searchCallback,
    required this.onSelected,
    this.showMic = false,
    this.onMicTap,
    required this.speech,
  });

  @override
  State<_SearchableSheetContent> createState() => _SearchableSheetContentState();
}

class _SearchableSheetContentState extends State<_SearchableSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _results = [];
  bool _isLoading = false;
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.searchCallback(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startVoiceSearchInSheet() async {
    if (_isListening || widget.onMicTap == null) return;
    
    setState(() => _isListening = true);
    
    final options = stt.SpeechListenOptions(
      partialResults: true,
    );
    
    await widget.speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          _searchController.text = _recognizedText;
        });
        _performSearch(_recognizedText);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: options,
    );
  }

  void _stopListeningInSheet() {
    widget.speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10)
            )
          ),
          Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _performSearch(val),
                    decoration: InputDecoration(
                      hintText: _isListening ? "Listening..." : "Type to search...",
                      border: InputBorder.none,
                      prefixIcon: Icon(_isListening ? Icons.mic : Icons.search, color: _isListening ? Colors.blue : Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                    ),
                  ),
                ),
                if (widget.showMic && widget.onMicTap != null)
                  _isListening
                    ? IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: _stopListeningInSheet,
                      )
                    : IconButton(
                        icon: Icon(Icons.mic, color: Colors.blue[700]),
                        onPressed: _startVoiceSearchInSheet,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty 
                  ? Center(child: Text("No results found", style: GoogleFonts.poppins(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_results[index], style: GoogleFonts.poppins(fontSize: 14)),
                          onTap: () {
                            widget.onSelected(_results[index]);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
          )
        ],
      ),
    );
  }
}