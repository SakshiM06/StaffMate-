import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/services/approval_service.dart';
import 'package:staff_mate/api/ipd_service.dart';

class ApprovalQueueColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color midDarkBlue = Color(0xFF283593);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF5F7FA);
  static const Color errorRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color purple = Color(0xFF9C27B0);
  static const Color pink = Color(0xFFE91E63);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color tableHeaderBg = Color(0xFFE8EAF6);
  static const Color tableBorder = Color(0xFFE0E0E0);
  static const Color checkboxColor = Color(0xFF1A237E);
  static const Color drawerBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color menuItemHover = Color(0xFFE3F2FD);
  static const Color dividerColor = Color(0xFFEEEEEE);
  static const Color iconBlue = Color(0xFF1976D2);
  static const Color iconGreen = Color(0xFF388E3C);
  static const Color iconOrange = Color(0xFFF57C00);
  static const Color iconPurple = Color(0xFF7B1FA2);
  static const Color chipBlue = Color(0xFF2196F3);
  static const Color chipGreen = Color(0xFF4CAF50);
  static const Color chipRed = Color(0xFFF44336);
  static const Color chipYellow = Color(0xFFFFC107);
  static const Color chipPurple = Color(0xFF9C27B0);
}

class ApprovalQueuePage extends StatefulWidget {
  const ApprovalQueuePage({super.key});

  @override
  State<ApprovalQueuePage> createState() => _ApprovalQueuePageState();
}

class _ApprovalQueuePageState extends State<ApprovalQueuePage> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Refund', 'Discount'];

  final ApprovalService _approvalService = ApprovalService();

  final IpdService _ipdService = IpdService();
  List<dynamic> _refundDataList = [];
  bool _isLoadingRefunds = false;
  bool _isApprovingRefunds = false;
  String _refundApiError = '';
  int _unApprovedCount = 0;
  int _unPaidCount = 0;
  int _paidCount = 0;
  int _cancelledCount = 0;
  int _requestApprovedCount = 0;
  int _totalCount = 0;

  List<dynamic> _locationList = [];
  bool _isLoadingLocations = false;
  String _locationApiError = '';
  Map<int, String> _locationNameMap = {};
  Map<int, String> _locationAbbreviationMap = {};
  List<dynamic> _invoiceTypeList = [];
  bool _isLoadingInvoiceTypes = false;
  String _invoiceTypeApiError = '';
  Map<int, String> _invoiceTypeMap = {};
  List<dynamic> _locationInvoiceTypeList = [];
  List<dynamic> _practitionerList = [];
  bool _isLoadingPractitioners = false;
  String _practitionerApiError = '';
  Map<int, String> _practitionerNameMap = {};
  Map<int, Map<String, dynamic>> _practitionerDetailsMap = {};
  
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
    'Paid',
    'Cancelled',
    'Request Approved',
    'Un-Paid Approval',
    'Un-Approved Request'
  ];
  
  String _selectedStatus = 'All';
  String _selectedLocation = 'All'; 
  String _searchUHID = '';
  String _searchQuery = '';
  
  Map<int, bool> _selectedRefunds = {};
  bool _selectAll = false;
  
  final List<Map<String, dynamic>> _pendingDiscounts = [
    {
      'id': 'DISC-MED-001',
      'patient': 'Arjun Mehta',
      'amount': 15000.00,
      'originalAmount': 30000.00,
      'discountPercent': 50,
      'date': '2024-03-15',
      'reason': 'Senior citizen discount',
      'status': 'Pending',
      'requestedBy': 'Dr. Joshi',
      'approvedBy': 'Admin',
    },
    {
      'id': 'DISC-MED-002',
      'patient': 'Corporate Health Plan',
      'amount': 75000.00,
      'originalAmount': 100000.00,
      'discountPercent': 25,
      'date': '2024-03-14',
      'reason': 'Corporate package',
      'status': 'Pending',
      'requestedBy': 'Sales Team',
      'approvedBy': 'Management',
    },
    {
      'id': 'DISC-MED-003',
      'patient': 'Ananya Reddy',
      'amount': 9000.00,
      'originalAmount': 12000.00,
      'discountPercent': 25,
      'date': '2024-03-13',
      'reason': 'Staff family discount',
      'status': 'Pending',
      'requestedBy': 'HR Department',
      'approvedBy': 'Director',
    },
  ];

  DateTime _selectedFromDate = DateTime.now();
  DateTime _selectedToDate = DateTime.now();
  List<dynamic> _filteredRefunds = [];
  List<Map<String, dynamic>> _filteredDiscounts = [];


  bool _showFilters = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    
    _filteredRefunds = [];
    _selectedFromDate = DateTime(2026, 1, 1);
    _selectedToDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllDataOnPageLoad();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
  Future<void> _fetchAllDataOnPageLoad() async {
    debugPrint('=== DEBUG: _fetchAllDataOnPageLoad() called ===');
    
    await Future.wait([
      _fetchLocationData(),
      _fetchInvoiceTypeData(),
      _fetchPractitionerData(),
    ]);
    if (_locationNameMap.isNotEmpty) {
      setState(() {
        _selectedLocation = _locationNameMap.values.first;
      });
    }
    _fetchRefundData();
  }

  Future<void> _fetchRefundData() async {
    debugPrint('=== DEBUG: _fetchRefundData() called ===');
    
    if (_isLoadingRefunds) {
      debugPrint('=== DEBUG: Skipping fetch - already loading ===');
      return;
    }
    
    setState(() {
      _isLoadingRefunds = true;
      _refundApiError = '';
    });

    try {
      debugPrint(' === DEBUG: Starting to fetch refund data from get-request-list API ===');
      
  
      final isValidSession = await _approvalService.validateSession();
      debugPrint('Session validation result: $isValidSession');
      
      if (!isValidSession) {
        debugPrint(' Session invalid - stopping API call');
        setState(() {
          _refundApiError = 'Session expired. Please login again.';
          _isLoadingRefunds = false;
        });
        return;
      }
      
      final fromDate = _selectedFromDate.toLocal().toString().split(' ')[0];
      final toDate = _selectedToDate.toLocal().toString().split(' ')[0];
      
      debugPrint('Fetching refunds from $fromDate to $toDate');
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        setState(() {
          _refundApiError = 'User ID not found. Please login again.';
          _isLoadingRefunds = false;
        });
        return;
      }
      
      debugPrint(' User ID for API: $userId');
      
      debugPrint(' === DEBUG: Calling getRefundGetRequestList API... ===');
      final response = await _approvalService.getRefundGetRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
        searchText: _searchQuery.isNotEmpty ? _searchQuery : null,
        refundStatus: _selectedStatus != 'All' ? _selectedStatus : null,
      );
      
      debugPrint(' === DEBUG: Refund API call completed ===');
      debugPrint('Response success: ${response['success']}');
      debugPrint('Response message: ${response['message']}');
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        
        if (data.containsKey('list')) {
          final listData = data['list'] as Map<String, dynamic>;
          final unApprovedCount = (listData['unApprovedCount'] as int?) ?? 0;
          final unPaidCount = (listData['unPaidCount'] as int?) ?? 0;

          List<dynamic> refundDataList = [];
          
          if (listData.containsKey('refundDataList') && listData['refundDataList'] is List) {
            refundDataList = listData['refundDataList'] as List<dynamic>;
            debugPrint('✅ Found refundDataList with ${refundDataList.length} items');
          } else if (listData.containsKey('list') && listData['list'] is List) {
            refundDataList = listData['list'] as List<dynamic>;
            debugPrint('✅ Found list field with ${refundDataList.length} items');
          } else {
            for (var key in listData.keys) {
              if (listData[key] is List) {
                refundDataList = listData[key] as List<dynamic>;
                debugPrint('Found list in key "$key" with ${refundDataList.length} items');
                break;
              }
            }
          }
          
          debugPrint('Successfully loaded ${refundDataList.length} refund requests');
          debugPrint('Counts - Unapproved: $unApprovedCount, Unpaid: $unPaidCount');
          
          int paidCount = 0;
          int cancelledCount = 0;
          int requestApprovedCount = 0;
          
          for (var r in refundDataList) {
            if (r is Map<String, dynamic>) {
              final status = r['refundStatus']?.toString().toLowerCase() ?? '';
              if (status == 'paid') {
                paidCount++;
              } else if (status == 'cancelled') {
                cancelledCount++;
              } else if (status == 'approved') {
                requestApprovedCount++;
              }
            }
          }
          
          debugPrint('Additional Counts - Paid: $paidCount, Cancelled: $cancelledCount, Request Approved: $requestApprovedCount');
          
          setState(() {
            _refundDataList = refundDataList;
            _totalCount = refundDataList.length;
            _unApprovedCount = unApprovedCount;
            _unPaidCount = unPaidCount;
            _paidCount = paidCount;
            _cancelledCount = cancelledCount;
            _requestApprovedCount = requestApprovedCount;
            _refundApiError = '';
            _selectedRefunds.clear();
            for (int i = 0; i < refundDataList.length; i++) {
              _selectedRefunds[i] = false;
            }
            _selectAll = false;
            
            _filterRefunds();
          });
        } else {
          debugPrint(' API response missing "list" field');
          setState(() {
            _refundApiError = 'Invalid API response format';
          });
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to fetch refund data';
        final statusCode = response['statusCode'] ?? 'No status code';
        debugPrint(' Refund API error: $errorMessage (Status: $statusCode)');
        setState(() {
          _refundApiError = errorMessage;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=== DEBUG: Exception in _fetchRefundData ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      setState(() {
        _refundApiError = 'Failed to load refund data: ${e.toString()}';
      });
    } finally {
      debugPrint('=== DEBUG: Setting _isLoadingRefunds to false ===');
      setState(() {
        _isLoadingRefunds = false;
      });
    }
  }

  // Method to fetch location data from API
  Future<void> _fetchLocationData() async {
    debugPrint('=== DEBUG: _fetchLocationData() called ===');
    
    if (_isLoadingLocations) {
      debugPrint('=== DEBUG: Skipping location fetch - already loading ===');
      return;
    }
    
    setState(() {
      _isLoadingLocations = true;
      _locationApiError = '';
    });

    try {
      debugPrint('🔄 === DEBUG: Starting to fetch location data ===');
      
      final isValidSession = await _approvalService.validateSession();
      debugPrint('✅ Session validation result: $isValidSession');
      
      if (!isValidSession) {
        debugPrint('❌ Session invalid - stopping location API call');
        setState(() {
          _locationApiError = 'Session expired. Please login again.';
          _isLoadingLocations = false;
        });
        return;
      }
      
      debugPrint('=== DEBUG: Calling getLocationList API... ===');
      final locationList = await _approvalService.getLocationList();
      
      debugPrint(' === DEBUG: Location API call completed ===');
      debugPrint('Loaded ${locationList.length} locations');
     
      final locationNameMap = await _approvalService.getLocationMap();
      final locationAbbreviationMap = await _approvalService.getLocationAbbreviationMap();
      
      setState(() {
        _locationList = locationList;
        _locationNameMap = locationNameMap;
        _locationAbbreviationMap = locationAbbreviationMap;
        _locationApiError = '';
      });
      
    } catch (e, stackTrace) {
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      setState(() {
        _locationApiError = 'Failed to load location data: ${e.toString()}';
      });
    } finally {
      debugPrint('=== DEBUG: Setting _isLoadingLocations to false ===');
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _fetchInvoiceTypeData() async {    
    if (_isLoadingInvoiceTypes) {

      return;
    }
    
    setState(() {
      _isLoadingInvoiceTypes = true;
      _invoiceTypeApiError = '';
    });

    try {
      
      final isValidSession = await _approvalService.validateSession();
      debugPrint('Session validation result: $isValidSession');
      
      if (!isValidSession) {
        debugPrint('❌ Session invalid - stopping invoice type API call');
        setState(() {
          _invoiceTypeApiError = 'Session expired. Please login again.';
          _isLoadingInvoiceTypes = false;
        });
        return;
      }
      debugPrint('📡 === DEBUG: Calling getInvoiceTypeList API... ===');
      final invoiceTypeList = await _approvalService.getInvoiceTypeList();
      
      debugPrint('✅ === DEBUG: Invoice Type API call completed ===');
      debugPrint('Loaded ${invoiceTypeList.length} invoice types');
      
  
      final invoiceTypeMap = await _approvalService.getInvoiceTypeMap();
      
      setState(() {
        _invoiceTypeList = invoiceTypeList;
        _invoiceTypeMap = invoiceTypeMap;
        _invoiceTypeApiError = '';
      });
      
    } catch (e, stackTrace) {
      debugPrint('❌ === DEBUG: Exception in _fetchInvoiceTypeData ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      setState(() {
        _invoiceTypeApiError = 'Failed to load invoice type data: ${e.toString()}';
      });
    } finally {
      debugPrint('=== DEBUG: Setting _isLoadingInvoiceTypes to false ===');
      setState(() {
        _isLoadingInvoiceTypes = false;
      });
    }
  }
  Future<void> _fetchPractitionerData() async {
    
    if (_isLoadingPractitioners) {

      return;
    }
    
    setState(() {
      _isLoadingPractitioners = true;
      _practitionerApiError = '';
    });

    try {

      final practitionerList = await _ipdService.fetchPractitionerList();
      debugPrint('Loaded ${practitionerList.length} practitioners');
      
   
      final practitionerNameMap = <int, String>{};
      final practitionerDetailsMap = <int, Map<String, dynamic>>{};
      
      for (var practitioner in practitionerList) {
        if (practitioner is Map<String, dynamic>) {
          final id = practitioner['id'];
          final name = practitioner['name']?.toString() ?? '';
          final specialization = practitioner['specialization']?.toString() ?? '';
          final registrationNo = practitioner['registrationNo']?.toString() ?? '';
          
          if (id != null && name.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              practitionerNameMap[intId] = name;
              practitionerDetailsMap[intId] = {
                'name': name,
                'specialization': specialization,
                'registrationNo': registrationNo,
                ...practitioner,
              };
            }
          }
        }
      }
      
      setState(() {
        _practitionerList = practitionerList;
        _practitionerNameMap = practitionerNameMap;
        _practitionerDetailsMap = practitionerDetailsMap;
        _practitionerApiError = '';
      });
      
    } catch (e, stackTrace) {
      debugPrint('❌ === DEBUG: Exception in _fetchPractitionerData ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      setState(() {
        _practitionerApiError = 'Failed to load practitioner data: ${e.toString()}';
      });
    } finally {
      debugPrint('=== DEBUG: Setting _isLoadingPractitioners to false ===');
      setState(() {
        _isLoadingPractitioners = false;
      });
    }
  }

  void _filterRefunds() {
    List<dynamic> filtered = List.from(_refundDataList);
     if (_searchUHID.isNotEmpty) {
      final uhidQuery = _searchUHID.toLowerCase();
      filtered = filtered.where((refund) {
        if (refund is! Map<String, dynamic>) return false;
        
        final patientId = refund['patientId']?.toString().toLowerCase() ?? '';
        final uhid = refund['uhid']?.toString().toLowerCase() ?? '';
        
        return patientId.contains(uhidQuery) || uhid.contains(uhidQuery);
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((refund) {
        if (refund is! Map<String, dynamic>) return false;
        
        final patientName = refund['patientName']?.toString().toLowerCase() ?? '';
        final refundRequestId = refund['refundRequestId']?.toString().toLowerCase() ?? '';
        final patientId = refund['patientId']?.toString().toLowerCase() ?? '';
        final invoiceId = refund['invoiceId']?.toString().toLowerCase() ?? '';
        final refundNote = refund['refundNote']?.toString().toLowerCase() ?? '';    
        final locationId = refund['locationId'];
        bool locationMatch = false;
        if (locationId != null && _locationNameMap.isNotEmpty) {
          final locationName = _locationNameMap[locationId]?.toLowerCase() ?? '';
          final locationAbbr = _locationAbbreviationMap[locationId]?.toLowerCase() ?? '';
          locationMatch = locationName.contains(query) || locationAbbr.contains(query);
        }
        
        return patientName.contains(query) ||
               refundRequestId.contains(query) ||
               patientId.contains(query) ||
               invoiceId.contains(query) ||
               refundNote.contains(query) ||
               locationMatch;
      }).toList();
    }
    
    setState(() {
      _filteredRefunds = filtered;
    });
  }

  Color _getStatusColor(String? status) {
    final statusLower = status?.toLowerCase() ?? '';
    
    switch (statusLower) {
      case 'approved':
      case 'request approved':
        return ApprovalQueueColors.successGreen;
      case 'rejected':
        return ApprovalQueueColors.errorRed;
      case 'pending':
      case 'un-approved request':
        return ApprovalQueueColors.warningOrange;
      case 'paid':
        return ApprovalQueueColors.accentTeal;
      case 'cancelled':
        return ApprovalQueueColors.errorRed;
      case 'un-paid approval':
        return ApprovalQueueColors.infoBlue;
      default:
        return ApprovalQueueColors.textBodyColor;
    }
  }
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      final date = DateTime.tryParse(dateString);
      if (date == null) return dateString;
      
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      final date = DateTime.tryParse(dateString);
      if (date == null) return dateString;
      
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
  String _formatIndianCurrency(double? amount) {
    if (amount == null) return '₹0.00';
    
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String _getLocationName(int? locationId) {
    if (locationId == null) return 'N/A';
    
    if (_locationNameMap.isNotEmpty) {
      return _locationNameMap[locationId] ?? 'Location $locationId';
    }
    
    return 'Location $locationId';
  }

  String _getLocationAbbreviation(int? locationId) {
    if (locationId == null) return '';
    
    if (_locationAbbreviationMap.isNotEmpty) {
      return _locationAbbreviationMap[locationId] ?? '';
    }
    
    return '';
  }

  String _getInvoiceTypeName(dynamic invoiceTypeData) {
    if (invoiceTypeData == null) return ' ';
    
    if (invoiceTypeData is String) {
      if (invoiceTypeData.isEmpty) return ' ';
      
      if (_invoiceTypeMap.isNotEmpty) {
        final entry = _invoiceTypeMap.entries.firstWhere(
          (entry) => entry.value.toLowerCase() == invoiceTypeData.toLowerCase(),
          orElse: () => const MapEntry(0, ''),
        );
        if (entry.value.isNotEmpty) return entry.value;
      }
      
      final intId = int.tryParse(invoiceTypeData);
      if (intId != null && _invoiceTypeMap.isNotEmpty) {
        return _invoiceTypeMap[intId] ?? 'Type $intId';
      }
      
      return invoiceTypeData;
    }
    
    if (invoiceTypeData is int) {
      if (_invoiceTypeMap.isNotEmpty) {
        return _invoiceTypeMap[invoiceTypeData] ?? 'Type $invoiceTypeData';
      }
      return 'Type $invoiceTypeData';
    }
    
    if (invoiceTypeData is double || invoiceTypeData is num) {
      final intId = invoiceTypeData.toInt();
      if (_invoiceTypeMap.isNotEmpty) {
        return _invoiceTypeMap[intId] ?? 'Type $intId';
      }
      return 'Type $intId';
    }
    
    return ' ';
  }

  String getInvoiceTypeFromRefund(Map<String, dynamic> refund) {
    final invoiceTypeData = refund['invoice_type_id'] ?? 
                           refund['invoiceType'] ?? 
                           refund['invoiceTypeId'] ??
                           refund['invoiceTypeName'] ??
                           refund['invoice_type_name'];
    
    if (invoiceTypeData == null) return 'N/A';
    
    return _getInvoiceTypeName(invoiceTypeData);
  }
  String _getPractitionerName(int? practitionerId) {
    if (practitionerId == null || _practitionerNameMap.isEmpty) return 'N/A';
    
    return _practitionerNameMap[practitionerId] ?? 'N/A';
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTab = index;
    });
  }
  void _handleViewClick() {
    _fetchRefundData();
  }
  void _handleSelectAll(bool? value) {
    if (value != null) {
      setState(() {
        _selectAll = value;
        for (int i = 0; i < _filteredRefunds.length; i++) {
          _selectedRefunds[i] = value;
        }
      });
    }
  }

  void _handleCheckboxChange(int index, bool? value) {
    if (value != null) {
      setState(() {
        _selectedRefunds[index] = value;
        
        bool allSelected = true;
        for (int i = 0; i < _filteredRefunds.length; i++) {
          if (_selectedRefunds[i] != true) {
            allSelected = false;
            break;
          }
        }
        _selectAll = allSelected;
      });
    }
  }
  int get _selectedRefundsCount {
    int count = 0;
    for (int i = 0; i < _filteredRefunds.length; i++) {
      if (_selectedRefunds[i] == true) {
        count++;
      }
    }
    return count;
  }

  List<Map<String, dynamic>> get _selectedRefundsList {
    List<Map<String, dynamic>> selectedList = [];
    for (int i = 0; i < _filteredRefunds.length; i++) {
      if (_selectedRefunds[i] == true) {
        selectedList.add(_filteredRefunds[i] as Map<String, dynamic>);
      }
    }
    return selectedList;
  }
  void _approveSelectedRefunds() {
    if (_selectedRefundsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select refunds to approve',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ApprovalQueueColors.warningOrange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ApproveRefundNoteDialog(
        selectedCount: _selectedRefundsCount,
        onApprove: (note) {
          _processApproveSelectedRefunds(note);
        },
      ),
    );
  }
  Future<void> _processApproveSelectedRefunds(String note) async {
    if (_selectedRefundsCount == 0) return;
    
    setState(() {
      _isApprovingRefunds = true;
    });

    try {
      final selectedRefunds = _selectedRefundsList;
      
      final response = await _approvalService.approveAllRefunds(
        refundList: selectedRefunds,
        approvedNotes: note,
      );
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Successfully approved ${selectedRefunds.length} refund(s)',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: ApprovalQueueColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        
        await _fetchRefundData();
        
        _showApprovalSuccessDialog(selectedRefunds.length, note);
        
      } else {
        final errorMessage = response['message'] ?? 'Failed to approve refunds';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ $errorMessage',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: ApprovalQueueColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ApprovalQueueColors.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _selectAll = false;
        for (int i = 0; i < _filteredRefunds.length; i++) {
          _selectedRefunds[i] = false;
        }
        _isApprovingRefunds = false;
      });
    }
  }

  void _showApprovalSuccessDialog(int approvedCount, String note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '✅ Approval Successful',
          style: GoogleFonts.poppins(
            color: ApprovalQueueColors.successGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully approved $approvedCount refund(s)',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 8),
            if (note.isNotEmpty) ...[
              Text(
                'Approval Note:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: GoogleFonts.poppins(
                  fontStyle: FontStyle.italic,
                  color: ApprovalQueueColors.textBodyColor,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'The refund status has been updated to "Approved".',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ApprovalQueueColors.textBodyColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: ApprovalQueueColors.primaryDarkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatusCard(String title, int count, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (title == 'ALL') {
            _selectedStatus = 'All';
          } else if (title == 'CANCELLED') {
            _selectedStatus = 'Cancelled';
          } else if (title == 'UN-APPROVED') {
            _selectedStatus = 'Un-Approved Request';
          } else if (title == 'UN-PAID') {
            _selectedStatus = 'Un-Paid Approval';
          } else if (title == 'PAID') {
            _selectedStatus = 'Paid';
          } else if (title == 'APPROVED') {
            _selectedStatus = 'Request Approved';
          }
        });
        _fetchRefundData();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 70),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCompactHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ApprovalQueueColors.primaryDarkBlue, ApprovalQueueColors.midDarkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Approval Queue',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTabChange(index),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _selectedTab == index
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == index
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            _tabs[index],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == index
                                  ? ApprovalQueueColors.primaryDarkBlue
                                  : Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ApprovalQueueColors.lightGreyColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search UHID, patient, invoice...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ApprovalQueueColors.textBodyColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: ApprovalQueueColors.textBodyColor,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _filterRefunds();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: ApprovalQueueColors.primaryDarkBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: _handleViewClick,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 18,
              ),
              tooltip: 'Refresh',
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: ApprovalQueueColors.accentTeal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(
                _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                color: Colors.white,
                size: 18,
              ),
              tooltip: 'Filters',
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilters() {
    if (!_showFilters) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ApprovalQueueColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: ApprovalQueueColors.lightGreyColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ApprovalQueueColors.tableBorder),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 18, color: ApprovalQueueColors.textBodyColor),
                        items: _statusOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue!;
                          });
                        },
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
                    Text(
                      'Location',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ApprovalQueueColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: ApprovalQueueColors.lightGreyColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ApprovalQueueColors.tableBorder),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedLocation,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 18, color: ApprovalQueueColors.textBodyColor),
                        items: ['All', ..._locationNameMap.values].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value.length > 20 ? '${value.substring(0, 20)}...' : value,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLocation = newValue!;
                          });
                        },
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
                    Text(
                      'From Date',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ApprovalQueueColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ApprovalQueueColors.lightGreyColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ApprovalQueueColors.tableBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedFromDate.day.toString().padLeft(2, '0')}/${_selectedFromDate.month.toString().padLeft(2, '0')}/${_selectedFromDate.year}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.textDark,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: ApprovalQueueColors.textBodyColor,
                            ),
                          ],
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
                    Text(
                      'To Date',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ApprovalQueueColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ApprovalQueueColors.lightGreyColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ApprovalQueueColors.tableBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedToDate.day.toString().padLeft(2, '0')}/${_selectedToDate.month.toString().padLeft(2, '0')}/${_selectedToDate.year}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.textDark,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: ApprovalQueueColors.textBodyColor,
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
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _selectedFromDate : _selectedToDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _selectedFromDate = picked;
        } else {
          _selectedToDate = picked;
        }
      });
    }
  }
  Widget _buildCompactStatusCards() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ApprovalQueueColors.primaryDarkBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: ApprovalQueueColors.primaryDarkBlue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Summary',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ApprovalQueueColors.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredRefunds.length} items',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: ApprovalQueueColors.textBodyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactStatusCard('ALL', _totalCount, ApprovalQueueColors.primaryDarkBlue),
                const SizedBox(width: 6),
                _buildCompactStatusCard('CANCELLED', _cancelledCount, ApprovalQueueColors.errorRed),
                const SizedBox(width: 6),
                _buildCompactStatusCard('UN-APPROVED', _unApprovedCount, ApprovalQueueColors.warningOrange),
                const SizedBox(width: 6),
                _buildCompactStatusCard('UN-PAID', _unPaidCount, ApprovalQueueColors.infoBlue),
                const SizedBox(width: 6),
                _buildCompactStatusCard('PAID', _paidCount, ApprovalQueueColors.accentTeal),
                const SizedBox(width: 6),
                _buildCompactStatusCard('APPROVED', _requestApprovedCount, ApprovalQueueColors.successGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRefundCard(Map<String, dynamic> refund, int index) {
    final patientName = refund['patientName']?.toString() ?? 'N/A';
    final patientId = refund['patientId']?.toString() ?? 'N/A';
    final uhid = refund['uhid']?.toString() ?? patientId;
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'N/A';
    final refundAmount = double.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0.0;
    final requestedDatetime = refund['requestedDatetime']?.toString() ?? '';
    final refundStatus = refund['refundStatus']?.toString() ?? 'Pending';
    final invoiceTypeName = getInvoiceTypeFromRefund(refund);
    
    int? locationId;
    String locationName = 'N/A';
    String locationAbbreviation = '';
    
    if (refund['locationId'] != null) {
      locationId = int.tryParse(refund['locationId'].toString());
      locationName = _getLocationName(locationId);
      locationAbbreviation = _getLocationAbbreviation(locationId);
    } else if (refund['location'] != null) {
      locationName = refund['location'].toString();
    } else if (refund['locationName'] != null) {
      locationName = refund['locationName'].toString();
    }

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 300),
      child: SlideAnimation(
        verticalOffset: 30.0,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(refundStatus).withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedRefunds[index] ?? false,
                        onChanged: _isApprovingRefunds 
                            ? null 
                            : (value) => _handleCheckboxChange(index, value),
                        activeColor: ApprovalQueueColors.checkboxColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          refundRequestId,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ApprovalQueueColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(refundStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(refundStatus).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          refundStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(refundStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: ApprovalQueueColors.primaryDarkBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'UHID: $uhid',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: ApprovalQueueColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationAbbreviation.isNotEmpty 
                                            ? '$locationName ($locationAbbreviation)'
                                            : locationName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: ApprovalQueueColors.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_outlined,
                                      size: 14,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        invoiceTypeName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: ApprovalQueueColors.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                    
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(requestedDatetime),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: ApprovalQueueColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: ApprovalQueueColors.textBodyColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatIndianCurrency(refundAmount),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: ApprovalQueueColors.primaryDarkBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _showCompactRefundDetails(refund),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ApprovalQueueColors.primaryDarkBlue,
                                      side: BorderSide(color: ApprovalQueueColors.primaryDarkBlue),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      'Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  
                                  ElevatedButton(
                                    onPressed: refundStatus.toLowerCase() == 'pending' && !_isApprovingRefunds
                                        ? () => _processRefund(refund)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: refundStatus.toLowerCase() == 'pending' && !_isApprovingRefunds
                                          ? ApprovalQueueColors.primaryDarkBlue
                                          : Colors.grey.shade300,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      refundStatus.toLowerCase() == 'pending' ? 'Approve' : refundStatus,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
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

  void _showCompactRefundDetails(Map<String, dynamic> refund) {
    final patientName = refund['patientName']?.toString() ?? 'N/A';
    final patientId = refund['patientId']?.toString() ?? 'N/A';
    final uhid = refund['uhid']?.toString() ?? patientId;
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'N/A';
    final refundAmount = double.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0.0;
    final requestedDatetime = refund['requestedDatetime']?.toString() ?? '';
    final requestedUserid = refund['requestedUserid']?.toString() ?? 'N/A';
    final approvedUserid = refund['approvedUserid']?.toString() ?? '';
    final approvedDateTime = refund['approvedDateTime']?.toString() ?? '';
    final refundStatus = refund['refundStatus']?.toString() ?? 'Pending';
    final refundNote = refund['refundNote']?.toString() ?? '';
    final refundFrom = refund['refundFrom']?.toString() ?? '';
    final approvedNote = refund['approvedNote']?.toString() ?? '';
    
    final invoiceTypeName = getInvoiceTypeFromRefund(refund);
    
    final invoiceId = refund['invoiceId']?.toString() ?? '';
    final abrivationId = refund['abrivationId']?.toString() ?? '';
    final addmissionId = refund['addmissionId']?.toString() ?? '';
    final patientType = refund['patientType']?.toString() ?? '';
    

    int? locationId;
    String locationName = 'N/A';
    String locationAbbreviation = '';
    
    if (refund['locationId'] != null) {
      locationId = int.tryParse(refund['locationId'].toString());
      locationName = _getLocationName(locationId);
      locationAbbreviation = _getLocationAbbreviation(locationId);
    } else if (refund['location'] != null) {
      locationName = refund['location'].toString();
    } else if (refund['locationName'] != null) {
      locationName = refund['locationName'].toString();
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ApprovalQueueColors.primaryDarkBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: ApprovalQueueColors.primaryDarkBlue, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Refund Details",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ApprovalQueueColors.textDark,
                          ),
                        ),
                        Text(
                          refundRequestId,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: ApprovalQueueColors.textBodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(refundStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      refundStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(refundStatus),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildCompactDetailRow('Patient Name', patientName),
                    _buildCompactDetailRow('UHID', uhid),
                    _buildCompactDetailRow('Patient Type', patientType.isNotEmpty ? patientType : 'N/A'),
                    _buildCompactDetailRow('Amount', _formatIndianCurrency(refundAmount)),
                    _buildCompactDetailRow('Invoice Type', invoiceTypeName),
                    _buildCompactDetailRow('Location', locationAbbreviation.isNotEmpty 
                        ? '$locationName ($locationAbbreviation)'
                        : locationName),
                    _buildCompactDetailRow('Requested Date', _formatDateTime(requestedDatetime)),
                    _buildCompactDetailRow('Requested By', requestedUserid),
                    if (approvedUserid.isNotEmpty)
                      _buildCompactDetailRow('Approved By', approvedUserid),
                    if (approvedDateTime.isNotEmpty)
                      _buildCompactDetailRow('Approved Date', _formatDateTime(approvedDateTime)),
                    if (invoiceId.isNotEmpty)
                      _buildCompactDetailRow('Invoice ID', invoiceId),
                    if (addmissionId.isNotEmpty)
                      _buildCompactDetailRow('Admission ID', addmissionId),
                    if (abrivationId.isNotEmpty)
                      _buildCompactDetailRow('Abbreviation ID', abrivationId),
                    _buildCompactDetailRow('Refund From', refundFrom.isNotEmpty ? refundFrom : 'N/A'),
                    const SizedBox(height: 12),
                    if (refundNote.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ApprovalQueueColors.lightGreyColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Request Note:",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ApprovalQueueColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              refundNote,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.textBodyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (approvedNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ApprovalQueueColors.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Approval Note:",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ApprovalQueueColors.successGreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              approvedNote,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: ApprovalQueueColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (refundStatus.toLowerCase() == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectRefund(refund);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ApprovalQueueColors.errorRed,
                          side: BorderSide(color: ApprovalQueueColors.errorRed),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Reject",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveRefund(refund);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Approve",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ApprovalQueueColors.lightGreyColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ApprovalQueueColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ApprovalQueueColors.textBodyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 0 ? Icons.receipt_long_outlined : Icons.discount_outlined,
              size: 48,
              color: ApprovalQueueColors.textBodyColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0 
                  ? (_refundDataList.isEmpty && _refundApiError.isEmpty
                      ? 'No refund requests found'
                      : 'No matching requests found')
                  : 'No discount requests found',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ApprovalQueueColors.textBodyColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedTab == 0 && _refundDataList.isEmpty && _refundApiError.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _handleViewClick,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  'Refresh',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildCompactLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: ApprovalQueueColors.primaryDarkBlue,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: ApprovalQueueColors.textBodyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactApiErrorIndicator(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ApprovalQueueColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ApprovalQueueColors.errorRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: ApprovalQueueColors.errorRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: ApprovalQueueColors.errorRed,
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
      key: _scaffoldKey,
      backgroundColor: ApprovalQueueColors.backgroundGrey,
      body: Column(
        children: [
          _buildCompactHeader(),

          if (_refundApiError.isNotEmpty)
            _buildCompactApiErrorIndicator('Refunds: $_refundApiError'),
          if (_locationApiError.isNotEmpty)
            _buildCompactApiErrorIndicator('Location: $_locationApiError'),
          if (_invoiceTypeApiError.isNotEmpty)
            _buildCompactApiErrorIndicator('Invoice Type: $_invoiceTypeApiError'),
          if (_practitionerApiError.isNotEmpty)
            _buildCompactApiErrorIndicator('Practitioner: $_practitionerApiError'),
      
          Expanded(
            child: AnimationLimiter(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildCompactSearchBar(),
                  _buildCompactFilters(),
                  _buildCompactStatusCards(),
                  
                  if (_selectedTab == 0 && _filteredRefunds.isNotEmpty && _selectedRefundsCount > 0)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ApprovalQueueColors.primaryDarkBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: ApprovalQueueColors.primaryDarkBlue.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedRefundsCount} refund${_selectedRefundsCount > 1 ? 's' : ''} selected',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isApprovingRefunds ? null : _approveSelectedRefunds,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ApprovalQueueColors.primaryDarkBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _isApprovingRefunds
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: ApprovalQueueColors.primaryDarkBlue,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.check_circle_outline, size: 14),
                            label: Text(
                              'Approve All',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_selectedTab == 0) ...[
                    if (_isLoadingRefunds)
                      _buildCompactLoadingState()
                    else if (_filteredRefunds.isEmpty)
                      Expanded(child: _buildCompactEmptyState())
                    else
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selectAll,
                                  onChanged: _isApprovingRefunds ? null : _handleSelectAll,
                                  activeColor: ApprovalQueueColors.checkboxColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Select All',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ApprovalQueueColors.textDark,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_filteredRefunds.length} items',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: ApprovalQueueColors.textBodyColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Refund list
                          ..._filteredRefunds.asMap().entries.map((entry) {
                            final index = entry.key;
                            final refund = entry.value as Map<String, dynamic>;
                            return _buildCompactRefundCard(refund, index);
                          }).toList(),
                          const SizedBox(height: 12),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processRefund(Map<String, dynamic> refund) {
    _showCompactRefundDetails(refund);
  }

  void _approveRefund(Map<String, dynamic> refund) {
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'Unknown';
    final selectedRefunds = [refund];
    
    showDialog(
      context: context,
      builder: (context) => ApproveRefundNoteDialog(
        selectedCount: 1,
        onApprove: (note) async {
          Navigator.pop(context);
          
          setState(() {
            _isApprovingRefunds = true;
          });

          try {
            debugPrint('🔄 Approving single refund: $refundRequestId');
            
            final response = await _approvalService.approveAllRefunds(
              refundList: selectedRefunds,
              approvedNotes: note,
            );
            
            if (response['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Refund $refundRequestId approved successfully',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: ApprovalQueueColors.successGreen,
                ),
              );
              
              await _fetchRefundData();
            } else {
              final errorMessage = response['message'] ?? 'Failed to approve refund';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ $errorMessage',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: ApprovalQueueColors.errorRed,
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '❌ Error: ${e.toString()}',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: ApprovalQueueColors.errorRed,
              ),
            );
          } finally {
            setState(() {
              _isApprovingRefunds = false;
            });
          }
        },
      ),
    );
  }

  void _rejectRefund(Map<String, dynamic> refund) {
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'Unknown';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Refund $refundRequestId rejected',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: ApprovalQueueColors.errorRed,
      ),
    );
  }
}

class ApproveRefundNoteDialog extends StatefulWidget {
  final int selectedCount;
  final Function(String) onApprove;

  const ApproveRefundNoteDialog({
    super.key,
    required this.selectedCount,
    required this.onApprove,
  });

  @override
  State<ApproveRefundNoteDialog> createState() => _ApproveRefundNoteDialogState();
}

class _ApproveRefundNoteDialogState extends State<ApproveRefundNoteDialog> {
  final TextEditingController _noteController = TextEditingController();
  bool _isApproving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ApprovalQueueColors.primaryDarkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: ApprovalQueueColors.primaryDarkBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approve ${widget.selectedCount} Refund${widget.selectedCount > 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ApprovalQueueColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Add an approval note (optional):',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ApprovalQueueColors.textBodyColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: ApprovalQueueColors.lightGreyColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Enter approval note here...',
                  hintStyle: GoogleFonts.poppins(
                    color: ApprovalQueueColors.textBodyColor,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                maxLines: 2,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ApprovalQueueColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isApproving
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ApprovalQueueColors.textBodyColor,
                      side: BorderSide(color: ApprovalQueueColors.dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isApproving
                        ? null
                        : () async {
                            setState(() {
                              _isApproving = true;
                            });
                            
                            await widget.onApprove(_noteController.text.trim());
                            
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isApproving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Approve Now',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}