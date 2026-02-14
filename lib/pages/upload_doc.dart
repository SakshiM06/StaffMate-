import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadDocScreen extends StatefulWidget {
  final Patient patient;
  const UploadDocScreen({super.key, required this.patient});

  @override
  State<UploadDocScreen> createState() => _UploadDocScreenState();
}

class _UploadDocScreenState extends State<UploadDocScreen> with SingleTickerProviderStateMixin {
  // Color constants
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textBodyColor = Color(0xFF4A5568);
  static const Color lightGreyColor = Color(0xFFF5F7FA);
  static const Color tableHeaderColor = Color(0xFFF8F9FA);
  static const Color tableBorderColor = Color(0xFFE9ECEF);
  static const Color successGreen = Color(0xFF28A745);
  static const Color errorRed = Color(0xFFDC3545);

  // Form variables
  String? _selectedType;
  final TextEditingController _docNoteController = TextEditingController();
  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  String? _fileType;
  int? _lastModified;
  bool _isUploading = false;
  String? _practitionerId;
  bool _loadingPractitioners = false;
  
  // Local file array to store multiple files before upload (matching React logic)
  List<Map<String, dynamic>> _localFileArray = [];
  List<Map<String, dynamic>> _fileList = [];
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Document type options
  final List<String> _documentTypes = [
    'GP Doc',
    'TP Doc',
    'Medical Report',
    'Consultant Report',
    'Assessment Report',
    'Investigation',
    'Admission Form',
    'Discharge Form',
    'Nursing',
    'Other'
  ];

  // IpdService instance
  final IpdService _ipdService = IpdService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
    
    // Load practitioner ID from patient object FIRST (this is the correct source)
    _loadPractitionerIdFromPatient();
    
    // Also load practitioner list for fallback (optional)
    _loadDefaultPractitionerId();
    
    // Load patient data from localStorage equivalent (SharedPreferences)
    _loadPatientData();
  }

  @override
  void dispose() {
    _docNoteController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    final patientDataString = prefs.getString('PatientDataArray');
    
    if (patientDataString != null) {
      try {
        final List<dynamic> patientDataArray = jsonDecode(patientDataString);
        debugPrint('✅ Loaded patient data array: $patientDataArray');
      } catch (e) {
        debugPrint('⚠️ Error parsing patient data: $e');
      }
    }
  }

  // NEW METHOD: Load practitioner ID directly from the patient object
  void _loadPractitionerIdFromPatient() {
    // Check if the patient object has practitionerId
    if (widget.patient.practitionerid != null && 
        widget.patient.practitionerid!.isNotEmpty) {
      _practitionerId = widget.patient.practitionerid;
      debugPrint('✅ Practitioner ID loaded from patient object: $_practitionerId');
      debugPrint('✅ Practitioner Name from patient: ${widget.patient.practitionername}');
    } else {
      debugPrint('⚠️ No practitioner ID in patient object, will try other sources');
      _practitionerId = '0';
    }
  }

  Future<void> _loadDefaultPractitionerId() async {
    // Only load if we don't already have a practitioner ID from patient object
    if (_practitionerId != null && _practitionerId != '0') {
      debugPrint('✅ Already have practitioner ID from patient: $_practitionerId, skipping fetch');
      return;
    }
    
    setState(() {
      _loadingPractitioners = true;
    });
    
    try {
      final practitioners = await _ipdService.fetchPractitionerList();
      
      if (practitioners.isNotEmpty) {
        // Try to find practitioner ID 13 specifically (from your successful example)
        dynamic selectedPractitioner;
        
        for (var p in practitioners) {
          final id = p['id']?.toString() ?? '';
          
          if (id == '13') {
            selectedPractitioner = p;
            debugPrint('✅ Found practitioner ID 13: ${p['practitionername']}');
            break;
          }
        }
        
        // If no ID 13 found, take the first one
        selectedPractitioner ??= practitioners.first;
        
        _practitionerId = selectedPractitioner['id']?.toString() ?? '0';
        debugPrint('✅ Fallback Practitioner ID loaded: $_practitionerId');
        debugPrint('✅ Fallback Practitioner Name: ${selectedPractitioner['practitionername']}');
      } else {
        _practitionerId = '0';
        debugPrint('⚠️ No practitioners found, using default ID: 0');
      }
    } catch (e) {
      debugPrint('❌ Error loading practitioners: $e');
      _practitionerId = '0';
    } finally {
      setState(() {
        _loadingPractitioners = false;
      });
    }
  }

  // ✅ FILE VALIDATION - Mirrors React logic exactly
  bool _validateFile(File file, String fileName, String fileType, int fileSize) {
    // Check file size (≤ 2MB)
    final fileMb = fileSize / (1024 * 1024);
    if (fileMb >= 2) {
      _showError("File Size must be less than or equal to 2mb....!");
      return false;
    }
    
    // Check file type
    final validTypes = [
      'application/pdf',
      'image/png',
      'image/jpeg',
      'image/jpg'
    ];
    
    if (!validTypes.contains(fileType)) {
      _showError("Please select correct file...!");
      return false;
    }
    
    return true;
  }

  // ✅ Normalize file type - JPEG → JPG (matches React logic)
  String _normalizeFileType(String fileType) {
    if (fileType == 'image/jpeg') {
      return 'image/jpg';
    }
    return fileType;
  }

  // ✅ Check if file already exists in local array
  bool _isFileExistInList(String fileName) {
    for (var file in _localFileArray) {
      if (file['fileName'] == fileName) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        
        // Determine MIME type
        String fileType = _getMimeType(fileName);
        
        // Validate file (size & type)
        if (!_validateFile(file, fileName, fileType, fileSize)) {
          return;
        }
        
        // Normalize file type (JPEG → JPG)
        fileType = _normalizeFileType(fileType);
        
        setState(() {
          _selectedFile = file;
          _fileName = fileName;
          _fileSize = fileSize;
          _fileType = fileType;
          _lastModified = DateTime.now().millisecondsSinceEpoch;
        });
        
        debugPrint('✅ File selected: $fileName, Type: $fileType, Size: ${fileSize / 1024}KB');
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // ✅ MAIN UPLOAD METHOD - FIXED to use correct practitioner ID
  Future<void> _uploadDocument() async {
    // First validate that a file is selected
    if (_selectedFile == null) {
      _showError("Please select a file to upload");
      setState(() {
        _isUploading = false;
      });
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Get user info from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userFullName = prefs.getString('userFullName') ?? 
                          prefs.getString('username') ?? 
                          'Staff User';
      
      // Get patient data from localStorage equivalent
      String patientDataString = prefs.getString('PatientDataArray') ?? '[]';
      List<dynamic> patientRecord = jsonDecode(patientDataString);
      
      // CRITICAL FIX: Start with values from the patient object passed to the screen
      String patient_id = widget.patient.patientId.toString();
      
      // Get practitioner ID from patient object FIRST (this is the most reliable source)
      String practitioner_id = widget.patient.practitionerid ?? '0';
      
      String condition_id = widget.patient.conditionId?.toString() ?? '0';
      String ipdId = widget.patient.admissionId;
      
      debugPrint('📋 Initial values from patient object:');
      debugPrint('   Patient ID: $patient_id');
      debugPrint('   Practitioner ID from patient: $practitioner_id');
      debugPrint('   Condition ID: $condition_id');
      debugPrint('   Admission ID: $ipdId');
      
      // ONLY use PatientDataArray if patient object doesn't have the values
      if ((practitioner_id == '0' || practitioner_id.isEmpty) && patientRecord.isNotEmpty) {
        debugPrint('⚠️ Practitioner ID missing from patient object, checking PatientDataArray...');
        for (var record in patientRecord) {
          if (record['practitionerid'] != null) {
            practitioner_id = record['practitionerid'].toString();
            debugPrint('✅ Found practitioner ID in PatientDataArray: $practitioner_id');
            break;
          }
        }
      }
      
      // If still no practitioner ID, use the fallback
      if (practitioner_id == '0' || practitioner_id.isEmpty) {
        if (_practitionerId != null && _practitionerId != '0') {
          practitioner_id = _practitionerId!;
          debugPrint('⚠️ Using fallback practitioner ID from API: $practitioner_id');
        }
      }

      // Get document note
      final uploadNotes = _docNoteController.text.trim();
      
      // Parse admission ID to integer
      int ipdOrOpdInt;
      try {
        ipdOrOpdInt = int.parse(ipdId);
      } catch (e) {
        ipdOrOpdInt = 0;
      }

      debugPrint('📤 Uploading with FINAL values:');
      debugPrint('   Patient ID: $patient_id');
      debugPrint('   Practitioner ID: $practitioner_id');
      debugPrint('   Condition ID: $condition_id');
      debugPrint('   IPD/OPD: $ipdOrOpdInt');
      debugPrint('   Document Type: ${_selectedType ?? 'Other'}');

      // Process file
      final bytes = await _selectedFile!.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Determine file type - normalize JPEG to JPG to match React logic
      String fileType = _fileType ?? _getMimeType(_fileName ?? '');
      fileType = _normalizeFileType(fileType);
      
      final fileDataUrl = 'data:$fileType;base64,$base64String';
      final fileName = _fileName ?? 'document';
      
      debugPrint('✅ File processed: $fileName, Type: $fileType, Size: ${bytes.length} bytes');

      // Create localFiles object
      Map<String, dynamic> localFiles = {
        'patientId': patient_id,
        'description': uploadNotes,
        'practitionerId': practitioner_id,
        'conditionId': condition_id,
        'uploadby': userFullName,
        'documentType': _selectedType ?? 'Other',
        'fileName': fileName,
        'ipdOrOpd': ipdOrOpdInt,
        'fileDataUrl': fileDataUrl,
        'fileType': fileType,
      };

      // Check if file already exists
      bool isFileExist = false;
      for (var file in _localFileArray) {
        if (file['fileName'] == localFiles['fileName']) {
          isFileExist = true;
          break;
        }
      }

      if (isFileExist) {
        _showError("File Already Added...!");
        setState(() {
          _isUploading = false;
        });
        return;
      } else {
        _localFileArray.add(localFiles);
        
        // Update fileList for UI
        Map<String, dynamic> fileNameList = {
          'id': '0',
          'name': fileName,
        };
        
        bool isFileExistInFileList = false;
        for (var file in _fileList) {
          if (file['name'] == fileNameList['name']) {
            isFileExistInFileList = true;
            break;
          }
        }
        
        if (!isFileExistInFileList) {
          _fileList.add(fileNameList);
        }
        
        debugPrint('✅ File added to local array. Total files: ${_localFileArray.length}');
      }

      // ACTUAL API CALL - Upload the document WITH FILE
      final result = await _ipdService.uploadDocument(
        patientId: patient_id,
        description: uploadNotes,
        documentType: _selectedType ?? 'Other',
        file: _selectedFile,
        ipdOrOpd: ipdOrOpdInt.toString(),
        uploadby: userFullName,
        practitionerId: practitioner_id,
        conditionId: condition_id,
      );

      if (result['success'] == true) {
        _showSuccess(result['message'] ?? 'Document uploaded successfully!');
        _resetForm();
        
        // Store updated local file array in SharedPreferences
        await prefs.setString('localFileArray', jsonEncode(_localFileArray));
      } else {
        _showError(result['message'] ?? 'Upload failed. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      _showError('Upload failed: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _selectedType = null;
      _selectedFile = null;
      _fileName = null;
      _fileSize = null;
      _fileType = null;
      _lastModified = null;
      _docNoteController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildModernDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: whiteColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: accentBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Document Type',
                  style: TextStyle(
                    fontSize: 15,
                    color: textBodyColor.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          selectedItemBuilder: (BuildContext context) {
            return _documentTypes.map((String value) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDocumentTypeIcon(value),
                        color: accentBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          items: _documentTypes.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedType == value
                            ? accentBlue.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDocumentTypeIcon(value),
                        color: _selectedType == value ? accentBlue : textBodyColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedType == value ? accentBlue : textDark,
                              fontWeight: _selectedType == value ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedType == value)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accentBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedType = newValue;
            });
          },
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lightGreyColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: accentBlue,
                size: 20,
              ),
            ),
          ),
          dropdownColor: whiteColor,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          style: const TextStyle(color: textDark, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildFileUploadArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: _pickFile,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _selectedFile == null ? whiteColor : successGreen.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedFile == null 
                  ? tableBorderColor
                  : successGreen.withOpacity(0.3),
              width: _selectedFile == null ? 1.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _selectedFile == null
                      ? accentBlue.withOpacity(0.1)
                      : successGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedFile == null
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 32,
                  color: _selectedFile == null ? accentBlue : successGreen,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFile == null
                    ? 'Upload Document'
                    : 'File Ready to Upload',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _selectedFile == null ? textDark : successGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFile == null
                    ? 'Tap to browse or drag and drop'
                    : 'Tap to change file',
                style: TextStyle(
                  fontSize: 14,
                  color: textBodyColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedFile != null) ...[
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: successGreen,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        _selectedFile == null
                            ? 'Supported: PNG, JPG, PDF (Max 2MB)'
                            : '✓ $_fileName (${_formatFileSize(_fileSize)})',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedFile == null ? textBodyColor : successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)}KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB';
  }

  IconData _getDocumentTypeIcon(String type) {
    switch (type) {
      case 'GP Doc':
      case 'TP Doc':
        return Icons.description_outlined;
      case 'Medical Report':
      case 'Consultant Report':
      case 'Assessment Report':
        return Icons.medical_information_outlined;
      case 'Investigation':
        return Icons.science_outlined;
      case 'Admission Form':
      case 'Discharge Form':
        return Icons.assignment_outlined;
      case 'Nursing':
        return Icons.local_hospital_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            whiteColor,
            lightGreyColor.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tableBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentBlue.withOpacity(0.2),
                  lightBlue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.patientname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MRN: ${widget.patient.patientId} • Admission: ${widget.patient.admissionId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.patient.practitionerid != null && 
                    widget.patient.practitionerid!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Practitioner: ${widget.patient.practitionername ?? widget.patient.practitionerid}',
                      style: TextStyle(
                        fontSize: 10,
                        color: successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreyColor,
      appBar: AppBar(
        title: const Text(
          'Upload Document',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: whiteColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        centerTitle: false,
        automaticallyImplyLeading: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: tableBorderColor,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lightGreyColor,
                whiteColor,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPatientInfoCard(),
                      const SizedBox(height: 24),
                      
                      // Document Type Selection
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: const Text(
                          'Document Type',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      _buildModernDropdown(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Optional - Defaults to "Other" if not selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: textBodyColor.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Document Note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: const Text(
                          'Document Note',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: whiteColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _docNoteController,
                          maxLines: 4,
                          style: const TextStyle(
                            fontSize: 15,
                            color: textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter description or notes (optional)...',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: textBodyColor.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: whiteColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: accentBlue.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            suffixIcon: _docNoteController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                      color: textBodyColor.withOpacity(0.7),
                                    ),
                                    onPressed: () {
                                      _docNoteController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lightGreyColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_docNoteController.text.length}/500',
                            style: TextStyle(
                              fontSize: 11,
                              color: textBodyColor.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // File Upload
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: const Text(
                          'Attach File',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      _buildFileUploadArea(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Supported formats: PNG, JPG, JPEG, PDF (Max 2MB)',
                          style: TextStyle(
                            fontSize: 12,
                            color: textBodyColor.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Upload Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentBlue.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isUploading || _loadingPractitioners ? null : _uploadDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: whiteColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isUploading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(whiteColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Uploading...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: whiteColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_rounded,
                                      size: 22,
                                      color: whiteColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _loadingPractitioners 
                                          ? 'Loading Practitioner...' 
                                          : 'Upload Document',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: whiteColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accentBlue.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: accentBlue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'File must be ≤ 2MB. Supported formats: PNG, JPG, JPEG, PDF.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textBodyColor,
                                  height: 1.4,
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
          ),
        ),
      ),
    );
  }
}