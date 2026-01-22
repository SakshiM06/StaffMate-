// vitals_detail_page.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:staff_mate/models/patient.dart';
import '../models/vitals.dart';

class VitalsDetailPage extends StatefulWidget {
  final VitalsEntry vitals;

  const VitalsDetailPage({super.key, required this.vitals, required Patient patient});

  @override
  State<VitalsDetailPage> createState() => _VitalsDetailPageState();
}

class _VitalsDetailPageState extends State<VitalsDetailPage> {
  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  
  // Track current field for sequential voice input
  int _currentFieldIndex = 0;
  bool _sequentialMode = false;
  
  // List of fields for sequential voice input
  final List<Map<String, dynamic>> _fields = [
    {'label': 'Temperature (°F)', 'key': 'tempF'},
    {'label': 'Heart Rate', 'key': 'hr'},
    {'label': 'Respiratory Rate', 'key': 'rr'},
    {'label': 'Systolic BP', 'key': 'sysBp'},
    {'label': 'Diastolic BP', 'key': 'diaBp'},
    {'label': 'RBS', 'key': 'rbs'},
    {'label': 'SpO₂', 'key': 'spo2'},
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
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

  Future<void> _startListening({bool sequential = false}) async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device'),
          backgroundColor: Colors.orange,
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
          ),
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _sequentialMode = sequential;
      if (sequential && _currentFieldIndex >= _fields.length) {
        _currentFieldIndex = 0;
      }
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        // Process if we have text and speech indicates end
        if (result.finalResult && _recognizedText.isNotEmpty) {
          _processVoiceInput(_recognizedText);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      localeId: 'en_US',
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
      onSoundLevelChange: null,
    );
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processVoiceInput(String text) {
    if (text.isEmpty) return;

    String cleanedText = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[^\d\.\s]'), '')
        .trim();

    // Extract numbers from the speech
    final numbers = _extractNumbersFromText(cleanedText);
    
    if (numbers.isNotEmpty) {
      if (_sequentialMode && _currentFieldIndex < _fields.length) {
        // Update the current field in sequential mode
        _updateVitalsField(_fields[_currentFieldIndex]['key'], numbers.first.toString());
        
        // Move to next field or finish
        if (_currentFieldIndex < _fields.length - 1) {
          _currentFieldIndex++;
          
          // Continue with next field after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showNextFieldPrompt();
              _startListening(sequential: true);
            }
          });
        } else {
          // Finished all fields
          setState(() {
            _sequentialMode = false;
            _currentFieldIndex = 0;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All vitals recorded via voice!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Single field update - find which field was mentioned
        final fieldKey = _identifyFieldFromSpeech(text);
        if (fieldKey != null && numbers.isNotEmpty) {
          _updateVitalsField(fieldKey, numbers.first.toString());
        }
      }
    }
    
    _stopListening();
  }

  List<String> _extractNumbersFromText(String text) {
    // Extract numbers including decimals
    final regex = RegExp(r'\b\d+(\.\d+)?\b');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  String? _identifyFieldFromSpeech(String text) {
    final lowerText = text.toLowerCase();
    
    // Temperature patterns
    if (lowerText.contains('temp') || 
        lowerText.contains('temperature') || 
        lowerText.contains('fever') ||
        lowerText.contains('°f')) {
      return 'tempF';
    }
    
    // Heart rate patterns
    if (lowerText.contains('heart') || 
        lowerText.contains('hr') || 
        lowerText.contains('pulse') ||
        lowerText.contains('bpm')) {
      return 'hr';
    }
    
    // Respiratory rate patterns
    if (lowerText.contains('respiratory') || 
        lowerText.contains('rr') || 
        lowerText.contains('breathing') ||
        lowerText.contains('breath')) {
      return 'rr';
    }
    
    // Blood pressure patterns
    if (lowerText.contains('blood pressure') || 
        lowerText.contains('bp') || 
        lowerText.contains('systolic') ||
        lowerText.contains('sys')) {
      return 'sysBp';
    }
    
    if (lowerText.contains('diastolic') || 
        lowerText.contains('dia') || 
        lowerText.contains('low bp')) {
      return 'diaBp';
    }
    
    // Blood sugar patterns
    if (lowerText.contains('rbs') || 
        lowerText.contains('sugar') || 
        lowerText.contains('glucose') ||
        lowerText.contains('blood sugar')) {
      return 'rbs';
    }
    
    // Oxygen saturation patterns
    if (lowerText.contains('spo') || 
        lowerText.contains('oxygen') || 
        lowerText.contains('saturation') ||
        lowerText.contains('spO2')) {
      return 'spo2';
    }
    
    return null;
  }

  void _updateVitalsField(String fieldKey, String value) {
    // In a real app, you would update the backend here
    // For demo purposes, we'll just show a snackbar
    final field = _fields.firstWhere((f) => f['key'] == fieldKey, orElse: () => {'label': 'Unknown'});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${field['label']} updated to: $value'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startSequentialVoiceInput() {
    setState(() {
      _currentFieldIndex = 0;
      _sequentialMode = true;
    });
    
    _showNextFieldPrompt();
    _startListening(sequential: true);
  }

  void _showNextFieldPrompt() {
    if (_currentFieldIndex < _fields.length) {
      final currentField = _fields[_currentFieldIndex];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speak ${currentField['label']} value...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildRow(String label, String value, {String? fieldKey}) {
    final isCurrentField = _sequentialMode && 
        _currentFieldIndex < _fields.length && 
        _fields[_currentFieldIndex]['key'] == fieldKey;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentField ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isCurrentField ? Border.all(color: Colors.blue, width: 1) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (isCurrentField && _isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Listening...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isCurrentField ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
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
              const Text(
                'Voice Commands for Vitals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 15),
              _buildVoiceExample(
                'Single Value:',
                'Temperature ninety eight point six',
              ),
              _buildVoiceExample(
                'With Unit:',
                'Heart rate seventy two',
              ),
              _buildVoiceExample(
                'Blood Pressure:',
                'Blood pressure one twenty over eighty',
              ),
              const SizedBox(height: 20),
              const Text(
                'For Sequential Mode:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Say "ninety eight" for Temperature'),
                    Text('2. Say "seventy two" for Heart Rate'),
                    Text('3. Say "sixteen" for Respiratory Rate'),
                    Text('4. Say "one twenty" for Systolic BP'),
                    Text('5. Say "eighty" for Diastolic BP'),
                    Text('6. Say "one twenty" for RBS'),
                    Text('7. Say "ninety eight" for SpO₂'),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startSequentialVoiceInput();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Start Sequential Input',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (!_speechAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Note: Voice recognition may not be available on this device or emulator.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
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
            style: TextStyle(
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
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals Details'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          // Voice input button
          IconButton(
            onPressed: _isListening ? _stopListening : () => _startListening(sequential: false),
            icon: Icon(
              _isListening ? Icons.mic_off : Icons.mic,
              color: _isListening ? Colors.red : Colors.white,
            ),
            tooltip: 'Voice input for single field',
          ),
          IconButton(
            onPressed: _showVoiceTutorial,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Voice command help',
          ),
        ],
      ),
      body: Column(
        children: [
          // Voice status indicator
          if (_isListening)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sequentialMode 
                          ? 'Sequential mode: ${_fields[_currentFieldIndex]['label']}...'
                          : 'Listening... Say a value',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          
          if (!_speechAvailable)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Speech recognition is not available on this device',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Sequential input button
          if (!_isListening)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _startSequentialVoiceInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.mic, size: 20),
                label: const Text(
                  'Start Sequential Voice Input',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _buildRow("Patient Name", widget.vitals.patientName),
                  _buildRow("Date", '${widget.vitals.date.day}-${widget.vitals.date.month}-${widget.vitals.date.year}'),
                  _buildRow("Time", '${widget.vitals.hour}:${widget.vitals.minute.toString().padLeft(2, '0')}'),
                  const Divider(),
                  _buildRow("Temperature (°F)", widget.vitals.tempF, fieldKey: 'tempF'),
                  _buildRow("Heart Rate", widget.vitals.hr, fieldKey: 'hr'),
                  _buildRow("Respiratory Rate", widget.vitals.rr, fieldKey: 'rr'),
                  _buildRow("Systolic BP", widget.vitals.sysBp, fieldKey: 'sysBp'),
                  _buildRow("Diastolic BP", widget.vitals.diaBp, fieldKey: 'diaBp'),
                  _buildRow("RBS", widget.vitals.rbs, fieldKey: 'rbs'),
                  _buildRow("SpO₂", widget.vitals.spo2, fieldKey: 'spo2'),
                  
                  // Voice tutorial prompt
                  if (!_isListening && _recognizedText.isEmpty)
                    GestureDetector(
                      onTap: _showVoiceTutorial,
                      child: Container(
                        margin: const EdgeInsets.only(top: 30),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.record_voice_over,
                              size: 40,
                              color: Colors.blue[300],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Try Voice Input',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use voice commands to quickly update vitals values',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _startSequentialVoiceInput,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Start Sequential Input'),
                            ),
                          ],
                        ),
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