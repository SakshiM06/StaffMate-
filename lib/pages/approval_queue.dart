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
  
  // Refund data
  List<dynamic> _refundDataList = [];
  bool _isLoadingRefunds = false;
  bool _isProcessingAction = false;
  String _refundApiError = '';
  
  // Summary counts
  int _allCount = 0;
  int _cancelledCount = 0;
  int _unPaidCount = 0;
  int _unApprovedCount = 0;
  int _paidCount = 0;

  // Discount data
  List<dynamic> _discountDataList = [];
  bool _isLoadingDiscounts = false;
  bool _isApprovingDiscounts = false;
  String _discountApiError = '';
  int _discountNonAppliedCount = 0;
  int _discountNonApprovedCount = 0;
  int _discountTotalCount = 0;

  // Common data
  List<dynamic> _locationList = [];
  bool _isLoadingLocations = false;
  String _locationApiError = '';
  Map<int, String> _locationNameMap = {};
  Map<int, String> _locationAbbreviationMap = {};
  List<dynamic> _invoiceTypeList = [];
  bool _isLoadingInvoiceTypes = false;
  String _invoiceTypeApiError = '';
  Map<int, String> _invoiceTypeMap = {};
  List<dynamic> _practitionerList = [];
  bool _isLoadingPractitioners = false;
  String _practitionerApiError = '';
  Map<int, String> _practitionerNameMap = {};
  Map<int, Map<String, dynamic>> _practitionerDetailsMap = {};
  
  // Filter options for Refund tab
  final List<Map<String, dynamic>> _refundStatusOptions = [
    {'label': 'All', 'value': ''},
    {'label': 'Requested', 'value': '0'},
    {'label': 'Approved', 'value': '1'},
    {'label': 'Paid', 'value': '2'},
    {'label': 'Cancelled', 'value': '4'},
  ];
  
  // Discount status options
  final List<Map<String, dynamic>> _discountStatusOptions = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Requested', 'value': '1'},
    {'label': 'Approved', 'value': '2'},
    {'label': 'Applied', 'value': '3'},
  ];
  
  String _selectedRefundStatusValue = '';
  String _selectedDiscountStatusValue = 'all';
  
  String _selectedRefundSummary = 'ALL';
  
  String _selectedLocation = 'All'; 
  String _searchUHID = '';
  String _searchQuery = '';
  
  // Refund selection
  final Map<int, bool> _selectedRefunds = {};
  bool _selectAll = false;
  
  // Discount selection
  final Map<int, bool> _selectedDiscounts = {};
  bool _selectAllDiscounts = false;

  DateTime _selectedFromDate = DateTime.now();
  DateTime _selectedToDate = DateTime.now();
  List<dynamic> _filteredRefunds = [];
  List<dynamic> _filteredDiscounts = [];

  bool _showFilters = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Helper method to get selected discount status label
  String get _selectedDiscountStatusLabel {
    final option = _discountStatusOptions.firstWhere(
      (option) => option['value'] == _selectedDiscountStatusValue,
      orElse: () => const {'label': 'All', 'value': 'all'},
    );
    return option['label'] as String;
  }

  // Helper method to get selected discount status value for API
  String? get _selectedDiscountStatusApiValue {
    if (_selectedDiscountStatusValue == 'all') return null;
    return _selectedDiscountStatusValue;
  }

  // Helper method to map discount status code to string
  String _getDiscountStatusFromCode(int? statusCode) {
    if (statusCode == null) return 'Pending';
    
    switch (statusCode) {
      case 1:
        return 'Requested';
      case 2:
        return 'Approved';
      case 3:
        return 'Applied';
      default:
        return 'Pending';
    }
  }

  // Helper method to get discount type based on discountTypeFlag
  String _getDiscountType(int? discountTypeFlag) {
    if (discountTypeFlag == null) return 'N/A';
    
    switch (discountTypeFlag) {
      case 0:
        return 'Percentage';
      case 1:
        return 'Fixed Amount';
      case 2:
        return 'Free Service';
      default:
        return 'N/A';
    }
  }

  // Helper method to get refund display status
  String _getRefundDisplayStatus(Map<String, dynamic> refund) {
    final status = refund['refundStatus']?.toString().toUpperCase() ?? '';
    final isDeleted = refund['isdeleted'] == 1;
    
    if (isDeleted) {
      return 'Cancelled';
    }
    
    switch (status) {
      case 'PENDING':
      case 'REQUESTED':
        return 'Un-Approved Request';
      case 'APPROVED':
        return 'Un-Paid Approval';
      case 'PAID':
        return 'Paid';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Helper method to get raw status
  String _getRefundRawStatus(Map<String, dynamic> refund) {
    final status = refund['refundStatus']?.toString().toUpperCase() ?? '';
    final isDeleted = refund['isdeleted'] == 1;
    
    if (isDeleted) return 'CANCELLED';
    return status;
  }

  // Helper method to check if refund is actionable
  bool _isActionable(Map<String, dynamic> refund) {
    final status = refund['refundStatus']?.toString().toUpperCase() ?? '';
    final isDeleted = refund['isdeleted'] == 1;
    
    return !isDeleted && (status == 'PENDING' || status == 'REQUESTED' || status == 'APPROVED');
  }

  // Helper method to check if refund matches filter value
  bool _matchesRefundFilter(Map<String, dynamic> refund, String filterValue) {
    final status = refund['refundStatus']?.toString().toUpperCase() ?? '';
    final isDeleted = refund['isdeleted'] == 1;
    
    if (filterValue.isEmpty) {
      return true;
    }
    
    switch (filterValue) {
      case '0': // Requested
        return !isDeleted && (status == 'PENDING' || status == 'REQUESTED');
      case '1': // Approved
        return !isDeleted && status == 'APPROVED';
      case '2': // Paid
        return status == 'PAID';
      case '4': // Cancelled
        return isDeleted || status == 'CANCELLED';
      default:
        return true;
    }
  }

  // Helper method to check if refund matches summary selection
  bool _matchesSummary(Map<String, dynamic> refund, String summary) {
    if (summary == 'ALL') return true;
    
    final displayStatus = _getRefundDisplayStatus(refund);
    return displayStatus == summary;
  }

  @override
  void initState() {
    super.initState();
    
    _filteredRefunds = [];
    _filteredDiscounts = [];
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
    _fetchDiscountData();
  }

  Future<void> _fetchRefundData() async {
    debugPrint('=== DEBUG: _fetchRefundData() called ===');
    
    if (_isLoadingRefunds) {
      debugPrint('=== DEBUG: Skipping fetch - already loading ===');
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingRefunds = true;
      _refundApiError = '';
    });

    try {
      final isValidSession = await _approvalService.validateSession();
      
      if (!isValidSession) {
        if (!mounted) return;
        setState(() {
          _refundApiError = 'Session expired. Please login again.';
          _isLoadingRefunds = false;
        });
        return;
      }
      
      final fromDate = _selectedFromDate.toLocal().toString().split(' ')[0];
      final toDate = _selectedToDate.toLocal().toString().split(' ')[0];
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _refundApiError = 'User ID not found. Please login again.';
          _isLoadingRefunds = false;
        });
        return;
      }
      
      final response = await _approvalService.getRefundGetRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
        searchText: _searchQuery.isNotEmpty ? _searchQuery : null,
        refundStatus: null,
        refundDashboardStatus: null,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        
        if (data.containsKey('list')) {
          final listData = data['list'] as Map<String, dynamic>;

          List<dynamic> refundDataList = [];
          
          if (listData.containsKey('refundDataList') && listData['refundDataList'] is List) {
            refundDataList = listData['refundDataList'] as List<dynamic>;
          }
          
          // Calculate counts
          int paidCount = 0;
          int cancelledCount = 0;
          int unApprovedRequestCount = 0;
          int unPaidApprovalCount = 0;
          
          for (var r in refundDataList) {
            if (r is Map<String, dynamic>) {
              final rawStatus = r['refundStatus']?.toString().toUpperCase() ?? '';
              final isDeleted = r['isdeleted'] == 1;
              
              if (isDeleted || rawStatus == 'CANCELLED') {
                cancelledCount++;
              } else if (rawStatus == 'PAID') {
                paidCount++;
              } else if (rawStatus == 'APPROVED') {
                unPaidApprovalCount++;
              } else if (rawStatus == 'PENDING' || rawStatus == 'REQUESTED') {
                unApprovedRequestCount++;
              }
            }
          }
          
          if (!mounted) return;
          setState(() {
            _refundDataList = refundDataList;
            _allCount = refundDataList.length;
            _unApprovedCount = unApprovedRequestCount;
            _unPaidCount = unPaidApprovalCount;
            _paidCount = paidCount;
            _cancelledCount = cancelledCount;
            _refundApiError = '';
            _selectedRefunds.clear();
            for (int i = 0; i < refundDataList.length; i++) {
              _selectedRefunds[i] = false;
            }
            _selectAll = false;
            
            // Apply filters
            _applyFilters();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refundApiError = 'Failed to load refund data: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingRefunds = false;
      });
    }
  }

  // Apply all filters
  void _applyFilters() {
    debugPrint('=== APPLYING FILTERS ===');
    debugPrint('Summary selection: $_selectedRefundSummary');
    debugPrint('Status filter value: "$_selectedRefundStatusValue"');
    
    List<dynamic> filtered = List.from(_refundDataList);
    debugPrint('Initial refund count: ${filtered.length}');
    
    // Apply summary filter
    if (_selectedRefundSummary != 'ALL') {
      filtered = filtered.where((refund) {
        if (refund is! Map<String, dynamic>) return false;
        return _matchesSummary(refund, _selectedRefundSummary);
      }).toList();
      debugPrint('After summary filter: ${filtered.length} items');
    }
    
    // Apply status filter
    if (_selectedRefundStatusValue.isNotEmpty) {
      filtered = filtered.where((refund) {
        if (refund is! Map<String, dynamic>) return false;
        return _matchesRefundFilter(refund, _selectedRefundStatusValue);
      }).toList();
      debugPrint('After status filter: ${filtered.length} items');
    }
    
    // Apply search filters
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
        
        return patientName.contains(query) || refundRequestId.contains(query);
      }).toList();
    }
    
    // Apply location filter - FIXED
    if (_selectedLocation != 'All' && _locationNameMap.isNotEmpty) {
      debugPrint('Applying location filter: $_selectedLocation');
      final previousCount = filtered.length;
      
      filtered = filtered.where((refund) {
        if (refund is! Map<String, dynamic>) return false;
        
        // Get branchId from refund data
        final branchId = refund['branchId'];
        
        if (branchId != null) {
          // Try to get location name from branchId
          final locationName = _locationNameMap[branchId] ?? '';
          final locationAbbr = _locationAbbreviationMap[branchId] ?? '';
          
          // Check if location matches
          bool matches = locationName == _selectedLocation || 
                        locationAbbr == _selectedLocation ||
                        locationName.contains(_selectedLocation) ||
                        locationAbbr.contains(_selectedLocation);
          
          if (matches) {
            debugPrint('✅ Location match: ${refund['refundRequestId']} - branchId: $branchId, name: $locationName');
          }
          
          return matches;
        }
        
        // If no branchId, try other location fields
        final locationName = refund['locationName']?.toString() ?? '';
        final location = refund['location']?.toString() ?? '';
        
        return locationName == _selectedLocation || 
               location == _selectedLocation ||
               locationName.contains(_selectedLocation) ||
               location.contains(_selectedLocation);
      }).toList();
      
      debugPrint('After location filter: ${filtered.length} items (was $previousCount)');
    } else {
      debugPrint('Skipping location filter - selectedLocation: $_selectedLocation, locationMap size: ${_locationNameMap.length}');
    }
    
    if (!mounted) return;
    setState(() {
      _filteredRefunds = filtered;
    });
    debugPrint('Final filtered refunds: ${_filteredRefunds.length}');
  }

  Future<void> _fetchDiscountData() async {
    debugPrint('=== DEBUG: _fetchDiscountData() called ===');
    
    if (_isLoadingDiscounts) {
      debugPrint('=== DEBUG: Skipping fetch - already loading ===');
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingDiscounts = true;
      _discountApiError = '';
    });

    try {
      final isValidSession = await _approvalService.validateSession();
      
      if (!isValidSession) {
        if (!mounted) return;
        setState(() {
          _discountApiError = 'Session expired. Please login again.';
          _isLoadingDiscounts = false;
        });
        return;
      }
      
      final fromDate = _selectedFromDate.toLocal().toString().split(' ')[0];
      final toDate = _selectedToDate.toLocal().toString().split(' ')[0];
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final userName = prefs.getString('userName') ?? userId;
      
      if (userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _discountApiError = 'User ID not found. Please login again.';
          _isLoadingDiscounts = false;
        });
        return;
      }
      
      final statusValue = _selectedDiscountStatusApiValue;
      
      final response = await _approvalService.getDiscountDashboardData(
        fromDate: fromDate,
        toDate: toDate,
        userid: userName,
        userNumericId: userId,
        searchText: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: statusValue,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        
        if (data.containsKey('list')) {
          final listData = data['list'] as Map<String, dynamic>;
          final nonApplied = (listData['nonApplied'] as int?) ?? 0;
          final nonApproved = (listData['nonApproved'] as int?) ?? 0;

          List<dynamic> discountDataList = [];
          
          if (listData.containsKey('discountDashboardList') && listData['discountDashboardList'] is List) {
            discountDataList = listData['discountDashboardList'] as List<dynamic>;
          }
          
          if (!mounted) return;
          setState(() {
            _discountDataList = discountDataList;
            _discountTotalCount = discountDataList.length;
            _discountNonAppliedCount = nonApplied;
            _discountNonApprovedCount = nonApproved;
            _discountApiError = '';
            _selectedDiscounts.clear();
            for (int i = 0; i < discountDataList.length; i++) {
              _selectedDiscounts[i] = false;
            }
            _selectAllDiscounts = false;
            
            _filterDiscounts();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discountApiError = 'Failed to load discount data: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingDiscounts = false;
      });
    }
  }

  Future<void> _fetchLocationData() async {
    debugPrint('=== DEBUG: _fetchLocationData() called ===');
    
    if (_isLoadingLocations) {
      debugPrint('=== DEBUG: Skipping location fetch - already loading ===');
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocations = true;
      _locationApiError = '';
    });

    try {
      final isValidSession = await _approvalService.validateSession();
      
      if (!isValidSession) {
        if (!mounted) return;
        setState(() {
          _locationApiError = 'Session expired. Please login again.';
          _isLoadingLocations = false;
        });
        return;
      }
      
      final locationList = await _approvalService.getLocationList();
     
      final locationNameMap = await _approvalService.getLocationMap();
      final locationAbbreviationMap = await _approvalService.getLocationAbbreviationMap();
      
      debugPrint('Location maps - names: ${locationNameMap.length}, abbreviations: ${locationAbbreviationMap.length}');
      
      if (!mounted) return;
      setState(() {
        _locationList = locationList;
        _locationNameMap.clear();
        _locationNameMap.addAll(locationNameMap);
        _locationAbbreviationMap.clear();
        _locationAbbreviationMap.addAll(locationAbbreviationMap);
        _locationApiError = '';
      });
      
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted) return;
      setState(() {
        _locationApiError = 'Failed to load location data: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _fetchInvoiceTypeData() async {    
    if (_isLoadingInvoiceTypes) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingInvoiceTypes = true;
      _invoiceTypeApiError = '';
    });

    try {
      final isValidSession = await _approvalService.validateSession();
      
      if (!isValidSession) {
        if (!mounted) return;
        setState(() {
          _invoiceTypeApiError = 'Session expired. Please login again.';
          _isLoadingInvoiceTypes = false;
        });
        return;
      }
      
      final invoiceTypeList = await _approvalService.getInvoiceTypeList();
      final invoiceTypeMap = await _approvalService.getInvoiceTypeMap();
      
      if (!mounted) return;
      setState(() {
        _invoiceTypeList = invoiceTypeList;
        _invoiceTypeMap.clear();
        _invoiceTypeMap.addAll(invoiceTypeMap);
        _invoiceTypeApiError = '';
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceTypeApiError = 'Failed to load invoice type data: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingInvoiceTypes = false;
      });
    }
  }
  
  Future<void> _fetchPractitionerData() async {
    
    if (_isLoadingPractitioners) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingPractitioners = true;
      _practitionerApiError = '';
    });

    try {
      final practitionerList = await _ipdService.fetchPractitionerList();
      
      final practitionerNameMap = <int, String>{};
      final practitionerDetailsMap = <int, Map<String, dynamic>>{};
      
      for (var practitioner in practitionerList) {
        if (practitioner is Map<String, dynamic>) {
          final id = practitioner['id'];
          final name = practitioner['name']?.toString() ?? '';
          
          if (id != null && name.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              practitionerNameMap[intId] = name;
              practitionerDetailsMap[intId] = {
                'name': name,
                ...practitioner,
              };
            }
          }
        }
      }
      
      if (!mounted) return;
      setState(() {
        _practitionerList = practitionerList;
        _practitionerNameMap.clear();
        _practitionerNameMap.addAll(practitionerNameMap);
        _practitionerDetailsMap.clear();
        _practitionerDetailsMap.addAll(practitionerDetailsMap);
        _practitionerApiError = '';
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _practitionerApiError = 'Failed to load practitioner data: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingPractitioners = false;
      });
    }
  }

  void _filterDiscounts() {
    List<dynamic> filtered = List.from(_discountDataList);
    
    if (_searchUHID.isNotEmpty) {
      final uhidQuery = _searchUHID.toLowerCase();
      filtered = filtered.where((discount) {
        if (discount is! Map<String, dynamic>) return false;
        
        final patientId = discount['patientId']?.toString().toLowerCase() ?? '';
        final uhid = discount['abrivationId']?.toString().toLowerCase() ?? '';
        
        return patientId.contains(uhidQuery) || uhid.contains(uhidQuery);
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((discount) {
        if (discount is! Map<String, dynamic>) return false;
        
        final patientName = discount['patientName']?.toString().toLowerCase() ?? '';
        final discountId = discount['discountId']?.toString().toLowerCase() ?? '';
        
        return patientName.contains(query) || discountId.contains(query);
      }).toList();
    }
    
    // Filter by status
    if (_selectedDiscountStatusValue != 'all') {
      final statusValue = int.tryParse(_selectedDiscountStatusValue) ?? 0;
      filtered = filtered.where((discount) {
        if (discount is! Map<String, dynamic>) return false;
        final statusCode = discount['discountStatus'] as int?;
        return statusCode == statusValue;
      }).toList();
    }
    
    if (!mounted) return;
    setState(() {
      _filteredDiscounts = filtered;
    });
  }

  Color _getStatusColor(String? status) {
    final statusLower = status?.toLowerCase() ?? '';
    
    switch (statusLower) {
      case 'un-paid approval':
        return ApprovalQueueColors.successGreen;
      case 'un-approved request':
        return ApprovalQueueColors.warningOrange;
      case 'paid':
        return ApprovalQueueColors.accentTeal;
      case 'cancelled':
        return ApprovalQueueColors.errorRed;
      case 'requested':
        return ApprovalQueueColors.warningOrange;
      case 'approved':
        return ApprovalQueueColors.successGreen;
      case 'applied':
        return ApprovalQueueColors.accentTeal;
      default:
        return ApprovalQueueColors.textBodyColor;
    }
  }
  
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      if (dateString.contains('-') && dateString.contains(':')) {
        final parts = dateString.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('-');
          if (dateParts.length == 3) {
            final day = dateParts[0];
            final month = dateParts[1];
            final year = dateParts[2];
            return '$day/$month/$year';
          }
        }
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      if (dateString.contains('-') && dateString.contains(':')) {
        return dateString;
      }
      return dateString;
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
    
    if (_locationNameMap.containsKey(locationId)) {
      return _locationNameMap[locationId]!;
    }
    
    return 'Location $locationId';
  }

  String _getLocationAbbreviation(int? locationId) {
    if (locationId == null) return '';
    
    if (_locationAbbreviationMap.containsKey(locationId)) {
      return _locationAbbreviationMap[locationId]!;
    }
    
    return '';
  }

  String _getInvoiceTypeName(dynamic invoiceTypeData) {
    if (invoiceTypeData == null) return 'N/A';
    
    if (invoiceTypeData is String) {
      return invoiceTypeData;
    }
    
    if (invoiceTypeData is int) {
      if (_invoiceTypeMap.containsKey(invoiceTypeData)) {
        return _invoiceTypeMap[invoiceTypeData]!;
      }
      return 'Type $invoiceTypeData';
    }
    
    return invoiceTypeData.toString();
  }

  String getInvoiceTypeFromRefund(Map<String, dynamic> refund) {
    final invoiceTypeData = refund['invoiceType'] ?? 
                           refund['invoice_type'] ??
                           refund['invoiceTypeId'] ??
                           refund['invoiceTypeName'];
    
    if (invoiceTypeData == null) return 'N/A';
    return invoiceTypeData.toString();
  }

  String getInvoiceTypeFromDiscount(Map<String, dynamic> discount) {
    final invoiceTypeData = discount['invoiceType'] ?? 
                           discount['invoice_type'] ??
                           discount['invoiceTypeId'] ??
                           discount['invoiceTypeName'];
    
    if (invoiceTypeData == null) return 'N/A';
    return invoiceTypeData.toString();
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
    if (_selectedTab == 0) {
      _fetchRefundData();
    } else {
      _fetchDiscountData();
    }
  }
  
  void _handleSelectAll(bool? value) {
    if (value != null && mounted) {
      setState(() {
        if (_selectedTab == 0) {
          _selectAll = value;
          for (int i = 0; i < _filteredRefunds.length; i++) {
            _selectedRefunds[i] = value;
          }
        } else {
          _selectAllDiscounts = value;
          for (int i = 0; i < _filteredDiscounts.length; i++) {
            _selectedDiscounts[i] = value;
          }
        }
      });
    }
  }

  void _handleCheckboxChange(int index, bool? value) {
    if (value != null && mounted) {
      setState(() {
        if (_selectedTab == 0) {
          _selectedRefunds[index] = value;
          
          bool allSelected = true;
          for (int i = 0; i < _filteredRefunds.length; i++) {
            if (_selectedRefunds[i] != true) {
              allSelected = false;
              break;
            }
          }
          _selectAll = allSelected;
        } else {
          _selectedDiscounts[index] = value;
          
          bool allSelected = true;
          for (int i = 0; i < _filteredDiscounts.length; i++) {
            if (_selectedDiscounts[i] != true) {
              allSelected = false;
              break;
            }
          }
          _selectAllDiscounts = allSelected;
        }
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

  int get _selectedDiscountsCount {
    int count = 0;
    for (int i = 0; i < _filteredDiscounts.length; i++) {
      if (_selectedDiscounts[i] == true) {
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

  List<Map<String, dynamic>> get _selectedDiscountsList {
    List<Map<String, dynamic>> selectedList = [];
    for (int i = 0; i < _filteredDiscounts.length; i++) {
      if (_selectedDiscounts[i] == true) {
        selectedList.add(_filteredDiscounts[i] as Map<String, dynamic>);
      }
    }
    return selectedList;
  }
  
  // Cancel Refund method
  Future<void> _cancelRefund(Map<String, dynamic> refund) async {
    final refundId = refund['refundRequestId'] ?? 0;
    final patientName = refund['patientName']?.toString() ?? 'Unknown';
    
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (context) => CancelRefundDialog(
        refundId: refundId.toString(),
        patientName: patientName,
        onCancel: (reason) async {
          Navigator.pop(context);
          
          if (!mounted) return;
          
          setState(() {
            _isProcessingAction = true;
          });

          try {
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getString('userId') ?? '';
            final userName = prefs.getString('userName') ?? userId;
            
            final response = await _approvalService.cancelRefundRequest(
              id: refundId is int ? refundId : int.tryParse(refundId.toString()) ?? 0,
              reason: reason,
              userId: userName,
            );
            
            if (response['success'] == true) {
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Refund cancelled successfully',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.successGreen,
                  ),
                );
              }
              
              await _fetchRefundData();
            } else {
              if (mounted) {
                final errorMessage = response['message'] ?? 'Failed to cancel refund';
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ $errorMessage',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.errorRed,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: ApprovalQueueColors.errorRed,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() {
                _isProcessingAction = false;
              });
            }
          }
        },
      ),
    );
  }

  // Approve Refund method
  Future<void> _approveRefund(Map<String, dynamic> refund) async {
    final refundId = refund['refundRequestId'] ?? 0;
    final patientName = refund['patientName']?.toString() ?? 'Unknown';
    
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (context) => ApproveNoteDialog(
        title: 'Approve Refund',
        itemId: refundId.toString(),
        patientName: patientName,
        type: 'Refund',
        onApprove: (note) async {
          Navigator.pop(context);
          
          if (!mounted) return;
          
          setState(() {
            _isProcessingAction = true;
          });

          try {
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getString('userId') ?? '';
            final userName = prefs.getString('userName') ?? userId;
            
            final response = await _approvalService.approveDiscount(
              id: refundId is int ? refundId : int.tryParse(refundId.toString()) ?? 0,
              invoiceid: refund['invoiceId'] is int ? refund['invoiceId'] :
                        int.tryParse(refund['invoiceId']?.toString() ?? '0') ?? 0,
              patient_id: refund['patientId'] is int ? refund['patientId'] :
                         int.tryParse(refund['patientId']?.toString() ?? '0') ?? 0,
              practitionerid: 0,
              requested_userid: refund['requestedUserid']?.toString() ?? '',
              abrivationId: refund['uhid']?.toString() ?? refund['abrivationId']?.toString(),
              approve_note: note,
              approver_userid: userName,
              balanceAmount: 0,
              branch_id: refund['branchId'] as int? ?? 0,
              charge_discount_amount: refund['refundAmount'] is int ? refund['refundAmount'] :
                                     int.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0,
              delete_date_time: "",
              deleted: 0,
              deletedby: "",
              deleteremark: "",
              discount: refund['refundAmount']?.toString() ?? '0',
              discountAmt: refund['refundAmount'] is int ? refund['refundAmount'] :
                          int.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0,
              discountSms: false,
              discount_given_userid: refund['requestedUserid']?.toString(),
              discount_type: 1,
              discountstatus: 0,
              invoice_amount: refund['invoiceAmount'] is int ? refund['invoiceAmount'] :
                             int.tryParse(refund['invoiceAmount']?.toString() ?? '0') ?? 0,
              invoice_amount_after_discount: refund['invoiceAmount'] is int ? refund['invoiceAmount'] :
                                            int.tryParse(refund['invoiceAmount']?.toString() ?? '0') ?? 0,
              invoice_type: refund['invoiceType']?.toString() ?? '',
              patientname: refund['patientName']?.toString() ?? '',
              practitionername: refund['practitionerName']?.toString() ?? '',
              request_note: refund['refundNote']?.toString() ?? '',
              request_type: 'Refund',
              requested_date: refund['requestedDatetime']?.toString() ?? '',
              type: 'Refund',
            );

            if (mounted) {
              if (response['success'] == true) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Refund approved successfully',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.successGreen,
                  ),
                );
                
                await _fetchRefundData();
              } else {
                final errorMessage = response['message'] ?? 'Failed to approve refund';
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ $errorMessage',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.errorRed,
                  ),
                );
              }
            }
            
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: ApprovalQueueColors.errorRed,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() {
                _isProcessingAction = false;
              });
            }
          }
        },
      ),
    );
  }

  // Bulk approve refunds
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
    
    final actionableSelectedCount = _selectedRefundsList.where((refund) => 
      _isActionable(refund)).length;
    
    if (actionableSelectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected refunds are not in "Requested" or "Approved" status',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ApprovalQueueColors.warningOrange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ApproveNoteDialog(
        title: 'Approve Refunds',
        itemId: '${actionableSelectedCount} items',
        patientName: 'Bulk Approval',
        type: 'Refund',
        onApprove: (note) {
          _processBulkApproveRefunds(note);
        },
      ),
    );
  }

  Future<void> _processBulkApproveRefunds(String note) async {
    final selectedRefunds = _selectedRefundsList.where((refund) => 
      _isActionable(refund)).toList();
      
    if (selectedRefunds.isEmpty) return;
    
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      _isProcessingAction = true;
    });

    try {
      int successCount = 0;
      List<String> failedRefunds = [];
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final userName = prefs.getString('userName') ?? userId;

      for (var refund in selectedRefunds) {
        try {
          final refundId = refund['refundRequestId'] ?? 0;
          
          final response = await _approvalService.approveDiscount(
            id: refundId is int ? refundId : int.tryParse(refundId.toString()) ?? 0,
            invoiceid: refund['invoiceId'] is int ? refund['invoiceId'] :
                      int.tryParse(refund['invoiceId']?.toString() ?? '0') ?? 0,
            patient_id: refund['patientId'] is int ? refund['patientId'] :
                       int.tryParse(refund['patientId']?.toString() ?? '0') ?? 0,
            practitionerid: 0,
            requested_userid: refund['requestedUserid']?.toString() ?? '',
            abrivationId: refund['uhid']?.toString() ?? refund['abrivationId']?.toString(),
            approve_note: note,
            approver_userid: userName,
            balanceAmount: 0,
            branch_id: refund['branchId'] as int? ?? 0,
            charge_discount_amount: refund['refundAmount'] is int ? refund['refundAmount'] :
                                   int.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0,
            delete_date_time: "",
            deleted: 0,
            deletedby: "",
            deleteremark: "",
            discount: refund['refundAmount']?.toString() ?? '0',
            discountAmt: refund['refundAmount'] is int ? refund['refundAmount'] :
                        int.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0,
            discountSms: false,
            discount_given_userid: refund['requestedUserid']?.toString(),
            discount_type: 1,
            discountstatus: 0,
            invoice_amount: refund['invoiceAmount'] is int ? refund['invoiceAmount'] :
                           int.tryParse(refund['invoiceAmount']?.toString() ?? '0') ?? 0,
            invoice_amount_after_discount: refund['invoiceAmount'] is int ? refund['invoiceAmount'] :
                                          int.tryParse(refund['invoiceAmount']?.toString() ?? '0') ?? 0,
            invoice_type: refund['invoiceType']?.toString() ?? '',
            patientname: refund['patientName']?.toString() ?? '',
            practitionername: refund['practitionerName']?.toString() ?? '',
            request_note: refund['refundNote']?.toString() ?? '',
            request_type: 'Refund',
            requested_date: refund['requestedDatetime']?.toString() ?? '',
            type: 'Refund',
          );

          if (response['success'] == true) {
            successCount++;
          } else {
            failedRefunds.add(refundId.toString());
          }
        } catch (e) {
          failedRefunds.add(refund['refundRequestId']?.toString() ?? 'Unknown');
        }
      }
      
      if (mounted) {
        if (successCount > 0) {
          String successMessage = '✅ Successfully approved $successCount refund(s)';
          if (failedRefunds.isNotEmpty) {
            successMessage += ', ${failedRefunds.length} failed';
          }
          
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                successMessage,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: failedRefunds.isEmpty 
                  ? ApprovalQueueColors.successGreen 
                  : ApprovalQueueColors.warningOrange,
              duration: const Duration(seconds: 3),
            ),
          );
          
          await _fetchRefundData();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                '❌ Failed to approve refunds. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: ApprovalQueueColors.errorRed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '❌ Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: ApprovalQueueColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectAll = false;
          for (int i = 0; i < _filteredRefunds.length; i++) {
            _selectedRefunds[i] = false;
          }
          _isProcessingAction = false;
        });
      }
    }
  }

  void _approveSelectedDiscounts() {
    if (_selectedDiscountsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select discounts to approve',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ApprovalQueueColors.warningOrange,
        ),
      );
      return;
    }
    
    final requestedSelectedCount = _selectedDiscountsList.where((discount) {
      final statusCode = discount['discountStatus'] as int?;
      return statusCode == 1;
    }).length;
    
    if (requestedSelectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected discounts are not in "Requested" status',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ApprovalQueueColors.warningOrange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ApproveNoteDialog(
        title: 'Approve Discounts',
        itemId: '${requestedSelectedCount} items',
        patientName: 'Bulk Approval',
        type: 'Discount',
        onApprove: (note) {
          _processBulkApproveDiscounts(note);
        },
      ),
    );
  }

  Future<void> _processBulkApproveDiscounts(String note) async {
    final selectedDiscounts = _selectedDiscountsList.where((discount) {
      final statusCode = discount['discountStatus'] as int?;
      return statusCode == 1;
    }).toList();
    
    if (selectedDiscounts.isEmpty) return;
    
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      _isApprovingDiscounts = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final approverUserId = prefs.getString('userId') ?? '';
      final approverUserName = prefs.getString('userName') ?? approverUserId;
      
      if (approverUserId.isEmpty) {
        throw Exception('User ID not found. Please login again.');
      }

      int successCount = 0;
      List<String> failedDiscounts = [];

      for (var discount in selectedDiscounts) {
        try {
          final discountId = discount['discountId'] is int ? discount['discountId'] : 
                            int.tryParse(discount['discountId']?.toString() ?? '0') ?? 0;
          
          final invoiceAmount = discount['invoiceAmount'] is int ? discount['invoiceAmount'] :
                               int.tryParse(discount['invoiceAmount']?.toString() ?? '0') ?? 0;
          
          final afterDiscountAmount = discount['invoiceAmountAfterDiscount'] is int ? discount['invoiceAmountAfterDiscount'] :
                                     int.tryParse(discount['invoiceAmountAfterDiscount']?.toString() ?? '0') ?? 0;
          
          int chargeDiscountAmount = invoiceAmount - afterDiscountAmount;

          final response = await _approvalService.approveDiscount(
            id: discountId,
            invoiceid: discount['invoiceId'] is int ? discount['invoiceId'] :
                      int.tryParse(discount['invoiceId']?.toString() ?? '0') ?? 0,
            patient_id: discount['patientId'] is int ? discount['patientId'] :
                       int.tryParse(discount['patientId']?.toString() ?? '0') ?? 0,
            practitionerid: discount['practitionerId'] is int ? discount['practitionerId'] :
                           int.tryParse(discount['practitionerId']?.toString() ?? '0') ?? 0,
            requested_userid: discount['requestedUserid']?.toString() ?? '',
            abrivationId: discount['abrivationId']?.toString(),
            approve_note: note,
            approver_userid: approverUserName,
            balanceAmount: discount['balanceAmount'] as int? ?? 0,
            branch_id: discount['branchId'] as int? ?? 0,
            charge_discount_amount: chargeDiscountAmount,
            delete_date_time: "",
            deleted: 0,
            deletedby: "",
            deleteremark: "",
            discount: discount['discount']?.toString() ?? '0',
            discountAmt: discount['discountAmt'] as int? ?? 0,
            discountSms: false,
            discount_given_userid: discount['discountGivenUserid']?.toString(),
            discount_type: discount['discountTypeFlag'] as int? ?? 0,
            discountstatus: 0,
            invoice_amount: invoiceAmount,
            invoice_amount_after_discount: afterDiscountAmount,
            invoice_type: discount['invoiceType']?.toString() ?? '',
            patientname: discount['patientName']?.toString() ?? '',
            practitionername: discount['practitionerName']?.toString() ?? '',
            request_note: discount['requestNote']?.toString() ?? '',
            request_type: discount['requestType']?.toString() ?? '',
            requested_date: discount['requestedDate']?.toString() ?? '',
            type: discount['type']?.toString() ?? '',
          );

          if (response['success'] == true) {
            successCount++;
          } else {
            failedDiscounts.add('$discountId');
          }
        } catch (e) {
          failedDiscounts.add('${discount['discountId']}');
        }
      }
      
      if (mounted) {
        if (successCount > 0) {
          String successMessage = '✅ Successfully approved $successCount discount(s)';
          if (failedDiscounts.isNotEmpty) {
            successMessage += ', ${failedDiscounts.length} failed';
          }
          
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                successMessage,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: failedDiscounts.isEmpty 
                  ? ApprovalQueueColors.successGreen 
                  : ApprovalQueueColors.warningOrange,
              duration: const Duration(seconds: 3),
            ),
          );
          
          await _fetchDiscountData();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                '❌ Failed to approve discounts. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: ApprovalQueueColors.errorRed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '❌ Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: ApprovalQueueColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectAllDiscounts = false;
          for (int i = 0; i < _filteredDiscounts.length; i++) {
            _selectedDiscounts[i] = false;
          }
          _isApprovingDiscounts = false;
        });
      }
    }
  }

  Widget _buildCompactStatusCard(String title, int count, Color color) {
    final isSelected = _selectedRefundSummary == title;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRefundSummary = title;
        });
        _applyFilters();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 70),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.15), 
            width: isSelected ? 2 : 1,
          ),
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
                  hintText: 'Search UHID, patient, ${_selectedTab == 0 ? 'refund' : 'discount'} ID...',
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
                  if (_selectedTab == 0) {
                    _applyFilters();
                  } else {
                    _filterDiscounts();
                  }
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
                        value: _selectedTab == 0 ? _selectedRefundStatusValue : _selectedDiscountStatusValue,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 18, color: ApprovalQueueColors.textBodyColor),
                        items: _selectedTab == 0 
                            ? _refundStatusOptions.map((option) {
                                return DropdownMenuItem<String>(
                                  value: option['value'] as String,
                                  child: Text(
                                    option['label'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: ApprovalQueueColors.textDark,
                                    ),
                                  ),
                                );
                              }).toList()
                            : _discountStatusOptions.map((option) {
                                return DropdownMenuItem<String>(
                                  value: option['value'] as String,
                                  child: Text(
                                    option['label'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: ApprovalQueueColors.textDark,
                                    ),
                                  ),
                                );
                              }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            if (_selectedTab == 0) {
                              _selectedRefundStatusValue = newValue!;
                            } else {
                              _selectedDiscountStatusValue = newValue!;
                            }
                          });
                          if (_selectedTab == 0) {
                            _applyFilters();
                          } else {
                            _filterDiscounts();
                          }
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
                          if (_selectedTab == 0) {
                            _applyFilters();
                          } else {
                            _filterDiscounts();
                          }
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
          
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchUHID = '';
                    _selectedRefundStatusValue = '';
                    _selectedRefundSummary = 'ALL';
                    _selectedLocation = 'All';
                    _selectedFromDate = DateTime(2026, 1, 1);
                    _selectedToDate = DateTime.now();
                  });
                  if (_selectedTab == 0) {
                    _applyFilters();
                  } else {
                    _fetchDiscountData();
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  'Clear Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: ApprovalQueueColors.primaryDarkBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_selectedTab == 0) {
                    _fetchRefundData();
                  } else {
                    _fetchDiscountData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Apply',
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
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _selectedFromDate : _selectedToDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null && mounted) {
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
    if (_selectedTab == 0) {
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
                  'Refund Summary',
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
                  _buildCompactStatusCard('ALL', _allCount, ApprovalQueueColors.primaryDarkBlue),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('Un-Approved Request', _unApprovedCount, ApprovalQueueColors.warningOrange),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('Un-Paid Approval', _unPaidCount, ApprovalQueueColors.infoBlue),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('Paid', _paidCount, ApprovalQueueColors.accentTeal),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('Cancelled', _cancelledCount, ApprovalQueueColors.errorRed),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
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
                  'Discount Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ApprovalQueueColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredDiscounts.length} items',
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
                  _buildCompactStatusCard('ALL', _discountTotalCount, ApprovalQueueColors.primaryDarkBlue),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('NON-APPLIED', _discountNonAppliedCount, ApprovalQueueColors.warningOrange),
                  const SizedBox(width: 6),
                  _buildCompactStatusCard('NON-APPROVED', _discountNonApprovedCount, ApprovalQueueColors.infoBlue),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCompactRefundCard(Map<String, dynamic> refund, int index) {
    final patientName = refund['patientName']?.toString() ?? 'N/A';
    final patientId = refund['patientId']?.toString() ?? 'N/A';
    final uhid = refund['uhid']?.toString() ?? refund['abrivationId']?.toString() ?? patientId;
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'N/A';
    final refundAmount = double.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0.0;
    final requestedDatetime = refund['requestedDatetime']?.toString() ?? '';
    final invoiceTypeName = getInvoiceTypeFromRefund(refund);
    
    final displayStatus = _getRefundDisplayStatus(refund);
    
    final bool isActionable = _isActionable(refund);
    
    int? branchId = refund['branchId'];
    String locationName = _getLocationName(branchId);
    String locationAbbreviation = _getLocationAbbreviation(branchId);

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
                    color: _getStatusColor(displayStatus).withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isActionable)
                        Checkbox(
                          value: _selectedRefunds[index] ?? false,
                          onChanged: _isProcessingAction 
                              ? null 
                              : (value) => _handleCheckboxChange(index, value),
                          activeColor: ApprovalQueueColors.checkboxColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (isActionable)
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
                          color: _getStatusColor(displayStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(displayStatus).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          displayStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(displayStatus),
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
                                  
                                  if (isActionable) ...[
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      onPressed: _isProcessingAction ? null : () => _approveRefund(refund),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ApprovalQueueColors.successGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Approve',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      onPressed: _isProcessingAction ? null : () => _cancelRefund(refund),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ApprovalQueueColors.errorRed,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildCompactDiscountCard(Map<String, dynamic> discount, int index) {
    final discountId = discount['discountId']?.toString() ?? '#${index + 1}';
    final invoiceId = discount['invoiceId']?.toString() ?? 'N/A';
    final invoiceType = discount['invoiceType']?.toString() ?? 'N/A';
    final requestType = discount['requestType']?.toString() ?? 'N/A';
    final requestDate = discount['requestedDate']?.toString() ?? '';
    final requestedBy = discount['requestedUserid']?.toString() ?? 'N/A';
    final approvedDate = discount['approvedDate']?.toString() ?? '';
    final approvedBy = discount['approverUserid']?.toString() ?? '';
    final approvedNote = discount['approveNote']?.toString() ?? '';
    final patientName = discount['patientName']?.toString() ?? 'N/A';
    final uhid = discount['abrivationId']?.toString() ?? 'N/A';
    final drName = discount['practitionerName']?.toString() ?? 'N/A';
    final patientCategory = discount['payeeName']?.toString() ?? 'N/A';
    final reqNotes = discount['requestNote']?.toString() ?? '';
    
    final discountTypeFlag = discount['discountTypeFlag'] as int?;
    final discType = _getDiscountType(discountTypeFlag);
    
    final disc = discount['discount']?.toString() ?? 'N/A';
    final totalDiscountAmount = double.tryParse(discount['chargeDiscountAmount']?.toString() ?? '0') ?? 0.0;
    final invoiceAmount = double.tryParse(discount['invoiceAmount']?.toString() ?? '0') ?? 0.0;
    final afterDiscount = double.tryParse(discount['invoiceAmountAfterDiscount']?.toString() ?? '0') ?? 0.0;
    final statusCode = discount['discountStatus'] as int?;
    final status = _getDiscountStatusFromCode(statusCode);
    
    final isRequested = statusCode == 1;

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
                    color: _getStatusColor(status).withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isRequested)
                        Checkbox(
                          value: _selectedDiscounts[index] ?? false,
                          onChanged: _isApprovingDiscounts 
                              ? null 
                              : (value) => _handleCheckboxChange(index, value),
                          activeColor: ApprovalQueueColors.checkboxColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (isRequested)
                        const SizedBox(width: 4),
                      Text(
                        '#',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: ApprovalQueueColors.textBodyColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        discountId,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ApprovalQueueColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
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
                                Text(
                                  'UHID: $uhid',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: ApprovalQueueColors.textBodyColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Invoice ID',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: ApprovalQueueColors.textBodyColor,
                                ),
                              ),
                              Text(
                                invoiceId,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ApprovalQueueColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: ApprovalQueueColors.dividerColor),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDiscountInfoRow('Invoice Type', invoiceType),
                          ),
                          Expanded(
                            child: _buildDiscountInfoRow('Request Type', requestType),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDiscountInfoRow('Request Date', _formatDate(requestDate)),
                          ),
                          Expanded(
                            child: _buildDiscountInfoRow('Requested By', requestedBy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      if (approvedDate.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildDiscountInfoRow('Approved Date', _formatDate(approvedDate)),
                            ),
                            Expanded(
                              child: _buildDiscountInfoRow('Approved By', approvedBy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      
                      if (approvedNote.isNotEmpty) ...[
                        _buildDiscountInfoRow('Approved Note', approvedNote, fullWidth: true),
                        const SizedBox(height: 6),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDiscountInfoRow('Dr. Name', drName),
                          ),
                          Expanded(
                            child: _buildDiscountInfoRow('Patient Category', patientCategory),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      if (reqNotes.isNotEmpty) ...[
                        _buildDiscountInfoRow('Req. Notes', reqNotes, fullWidth: true),
                        const SizedBox(height: 6),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDiscountInfoRow('Disc. Type', discType),
                          ),
                          Expanded(
                            child: _buildDiscountInfoRow('Disc.', disc),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ApprovalQueueColors.lightGreyColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Discount',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                  ),
                                  Text(
                                    _formatIndianCurrency(totalDiscountAmount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ApprovalQueueColors.primaryDarkBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice Amount',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                  ),
                                  Text(
                                    _formatIndianCurrency(invoiceAmount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ApprovalQueueColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'After Discount',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: ApprovalQueueColors.textBodyColor,
                                    ),
                                  ),
                                  Text(
                                    _formatIndianCurrency(afterDiscount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ApprovalQueueColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _showCompactDiscountDetails(discount),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ApprovalQueueColors.primaryDarkBlue,
                              side: BorderSide(color: ApprovalQueueColors.primaryDarkBlue),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          const SizedBox(width: 8),
                          
                          if (isRequested)
                            ElevatedButton(
                              onPressed: !_isApprovingDiscounts
                                  ? () => _approveDiscount(discount)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                'Approve',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountInfoRow(String label, String value, {bool fullWidth = false}) {
    if (fullWidth) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                '$label:',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ApprovalQueueColors.textBodyColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: ApprovalQueueColors.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: ApprovalQueueColors.textBodyColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ApprovalQueueColors.textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showCompactRefundDetails(Map<String, dynamic> refund) {
    final patientName = refund['patientName']?.toString() ?? 'N/A';
    final patientId = refund['patientId']?.toString() ?? 'N/A';
    final uhid = refund['uhid']?.toString() ?? refund['abrivationId']?.toString() ?? patientId;
    final refundRequestId = refund['refundRequestId']?.toString() ?? 'N/A';
    final refundAmount = double.tryParse(refund['refundAmount']?.toString() ?? '0') ?? 0.0;
    final requestedDatetime = refund['requestedDatetime']?.toString() ?? '';
    final requestedUserid = refund['requestedUserid']?.toString() ?? 'N/A';
    final approvedUserid = refund['approvedUserid']?.toString() ?? '';
    final approvedDateTime = refund['approvedDateTime']?.toString() ?? '';
    final refundNote = refund['refundNote']?.toString() ?? '';
    final refundFrom = refund['refundFrom']?.toString() ?? '';
    final approvedNote = refund['approvedNote']?.toString() ?? '';
    final isDeleted = refund['isdeleted'] == 1;
    final cancelReason = refund['cancel_reason']?.toString() ?? '';
    final cancelDatetime = refund['cancel_datetime']?.toString() ?? '';
    final cancelUserid = refund['cancel_userid']?.toString() ?? '';
    
    final displayStatus = _getRefundDisplayStatus(refund);
    
    final bool isActionable = _isActionable(refund);
    
    final invoiceTypeName = getInvoiceTypeFromRefund(refund);
    
    final invoiceId = refund['invoiceId']?.toString() ?? '';
    final abrivationId = refund['abrivationId']?.toString() ?? '';
    final addmissionId = refund['addmissionId']?.toString() ?? '';
    final patientType = refund['patientType']?.toString() ?? '';

    int? branchId = refund['branchId'];
    String locationName = _getLocationName(branchId);
    String locationAbbreviation = _getLocationAbbreviation(branchId);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
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
                      color: _getStatusColor(displayStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(displayStatus),
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
                    
                    if (isDeleted) ...[
                      _buildCompactDetailRow('Cancelled By', cancelUserid.isNotEmpty ? cancelUserid : requestedUserid),
                      _buildCompactDetailRow('Cancelled Date', _formatDateTime(cancelDatetime.isNotEmpty ? cancelDatetime : requestedDatetime)),
                      if (cancelReason.isNotEmpty)
                        _buildCompactDetailRow('Cancel Reason', cancelReason),
                    ],
                    
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
              
              if (isActionable)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessingAction ? null : () {
                            Navigator.pop(context);
                            _cancelRefund(refund);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ApprovalQueueColors.errorRed,
                            side: BorderSide(color: ApprovalQueueColors.errorRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "Cancel Request",
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
                          onPressed: _isProcessingAction ? null : () {
                            Navigator.pop(context);
                            _approveRefund(refund);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompactDiscountDetails(Map<String, dynamic> discount) {
    final discountId = discount['discountId']?.toString() ?? 'N/A';
    final invoiceId = discount['invoiceId']?.toString() ?? 'N/A';
    final invoiceType = discount['invoiceType']?.toString() ?? 'N/A';
    final requestType = discount['requestType']?.toString() ?? 'N/A';
    final requestDate = discount['requestedDate']?.toString() ?? '';
    final requestedBy = discount['requestedUserid']?.toString() ?? 'N/A';
    final approvedDate = discount['approvedDate']?.toString() ?? '';
    final approvedBy = discount['approverUserid']?.toString() ?? '';
    final approvedNote = discount['approveNote']?.toString() ?? '';
    final patientName = discount['patientName']?.toString() ?? 'N/A';
    final uhid = discount['abrivationId']?.toString() ?? 'N/A';
    final drName = discount['practitionerName']?.toString() ?? 'N/A';
    final patientCategory = discount['payeeName']?.toString() ?? 'N/A';
    final reqNotes = discount['requestNote']?.toString() ?? '';
    
    final discountTypeFlag = discount['discountTypeFlag'] as int?;
    final discType = _getDiscountType(discountTypeFlag);
    
    final disc = discount['discount']?.toString() ?? 'N/A';
    final totalDiscountAmount = double.tryParse(discount['chargeDiscountAmount']?.toString() ?? '0') ?? 0.0;
    final invoiceAmount = double.tryParse(discount['invoiceAmount']?.toString() ?? '0') ?? 0.0;
    final afterDiscount = double.tryParse(discount['invoiceAmountAfterDiscount']?.toString() ?? '0') ?? 0.0;
    final statusCode = discount['discountStatus'] as int?;
    final status = _getDiscountStatusFromCode(statusCode);
    
    final isRequested = statusCode == 1;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
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
                    child: const Icon(Icons.discount, color: ApprovalQueueColors.primaryDarkBlue, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Discount Details",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ApprovalQueueColors.textDark,
                          ),
                        ),
                        Text(
                          '#$discountId',
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
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
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
                    _buildCompactDetailRow('Dr. Name', drName),
                    _buildCompactDetailRow('Patient Category', patientCategory),
                    const SizedBox(height: 8),
                    
                    _buildCompactDetailRow('Invoice ID', invoiceId),
                    _buildCompactDetailRow('Invoice Type', invoiceType),
                    _buildCompactDetailRow('Request Type', requestType),
                    _buildCompactDetailRow('Request Date', _formatDateTime(requestDate)),
                    _buildCompactDetailRow('Requested By', requestedBy),
                    
                    if (approvedDate.isNotEmpty) ...[
                      _buildCompactDetailRow('Approved Date', _formatDateTime(approvedDate)),
                      _buildCompactDetailRow('Approved By', approvedBy),
                    ],
                    
                    if (reqNotes.isNotEmpty)
                      _buildCompactDetailRow('Request Notes', reqNotes),
                    
                    if (approvedNote.isNotEmpty)
                      _buildCompactDetailRow('Approved Note', approvedNote),
                    
                    const SizedBox(height: 8),
                    _buildCompactDetailRow('Disc. Type', discType),
                    _buildCompactDetailRow('Disc.', disc),
                    
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ApprovalQueueColors.lightGreyColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildCompactDetailRow('Invoice Amount', _formatIndianCurrency(invoiceAmount)),
                          const SizedBox(height: 4),
                          _buildCompactDetailRow('Total Discount', _formatIndianCurrency(totalDiscountAmount)),
                          const SizedBox(height: 4),
                          _buildCompactDetailRow('After Discount', _formatIndianCurrency(afterDiscount)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (isRequested)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ApprovalQueueColors.errorRed,
                            side: BorderSide(color: ApprovalQueueColors.errorRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            _approveDiscount(discount);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ApprovalQueueColors.primaryDarkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
            width: 110,
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
                      : 'No matching refund requests found')
                  : (_discountDataList.isEmpty && _discountApiError.isEmpty
                      ? 'No discount requests found'
                      : 'No matching discount requests found'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ApprovalQueueColors.textBodyColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
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

  void _approveDiscount(Map<String, dynamic> discount) {
    final discountId = discount['discountId']?.toString() ?? 'Unknown';
    final patientName = discount['patientName']?.toString() ?? 'Unknown';
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (context) => ApproveNoteDialog(
        title: 'Approve Discount',
        itemId: discountId,
        patientName: patientName,
        type: 'Discount',
        onApprove: (note) async {
          Navigator.pop(context);
          
          if (!mounted) return;
          
          setState(() {
            _isApprovingDiscounts = true;
          });

          try {
            final prefs = await SharedPreferences.getInstance();
            final approverUserId = prefs.getString('userId') ?? '';
            final approverUserName = prefs.getString('userName') ?? approverUserId;
            
            if (approverUserId.isEmpty) {
              throw Exception('User ID not found. Please login again.');
            }

            final invoiceAmount = discount['invoiceAmount'] is int ? discount['invoiceAmount'] :
                                 int.tryParse(discount['invoiceAmount']?.toString() ?? '0') ?? 0;
            
            final afterDiscountAmount = discount['invoiceAmountAfterDiscount'] is int ? discount['invoiceAmountAfterDiscount'] :
                                       int.tryParse(discount['invoiceAmountAfterDiscount']?.toString() ?? '0') ?? 0;
            
            int chargeDiscountAmount = invoiceAmount - afterDiscountAmount;

            final response = await _approvalService.approveDiscount(
              id: discount['discountId'] is int ? discount['discountId'] : 
                  int.tryParse(discount['discountId']?.toString() ?? '0') ?? 0,
              invoiceid: discount['invoiceId'] is int ? discount['invoiceId'] :
                        int.tryParse(discount['invoiceId']?.toString() ?? '0') ?? 0,
              patient_id: discount['patientId'] is int ? discount['patientId'] :
                         int.tryParse(discount['patientId']?.toString() ?? '0') ?? 0,
              practitionerid: discount['practitionerId'] is int ? discount['practitionerId'] :
                             int.tryParse(discount['practitionerId']?.toString() ?? '0') ?? 0,
              requested_userid: discount['requestedUserid']?.toString() ?? '',
              abrivationId: discount['abrivationId']?.toString(),
              approve_note: note,
              approver_userid: approverUserName,
              balanceAmount: discount['balanceAmount'] as int? ?? 0,
              branch_id: discount['branchId'] as int? ?? 0,
              charge_discount_amount: chargeDiscountAmount,
              delete_date_time: "",
              deleted: 0,
              deletedby: "",
              deleteremark: "",
              discount: discount['discount']?.toString() ?? '0',
              discountAmt: discount['discountAmt'] as int? ?? 0,
              discountSms: false,
              discount_given_userid: discount['discountGivenUserid']?.toString(),
              discount_type: discount['discountTypeFlag'] as int? ?? 0,
              discountstatus: 0,
              invoice_amount: invoiceAmount,
              invoice_amount_after_discount: afterDiscountAmount,
              invoice_type: discount['invoiceType']?.toString() ?? '',
              patientname: discount['patientName']?.toString() ?? '',
              practitionername: discount['practitionerName']?.toString() ?? '',
              request_note: discount['requestNote']?.toString() ?? '',
              request_type: discount['requestType']?.toString() ?? '',
              requested_date: discount['requestedDate']?.toString() ?? '',
              type: discount['type']?.toString() ?? '',
            );

            if (mounted) {
              if (response['success'] == true) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Discount #$discountId approved successfully',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.successGreen,
                  ),
                );
                
                await _fetchDiscountData();
              } else {
                final errorMessage = response['message'] ?? 'Failed to approve discount';
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ $errorMessage',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: ApprovalQueueColors.errorRed,
                  ),
                );
              }
            }
            
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: ApprovalQueueColors.errorRed,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() {
                _isApprovingDiscounts = false;
              });
            }
          }
        },
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

          if (_refundApiError.isNotEmpty && _selectedTab == 0)
            _buildCompactApiErrorIndicator('Refunds: $_refundApiError'),
          if (_discountApiError.isNotEmpty && _selectedTab == 1)
            _buildCompactApiErrorIndicator('Discounts: $_discountApiError'),
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
                            onPressed: _isProcessingAction ? null : _approveSelectedRefunds,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ApprovalQueueColors.primaryDarkBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _isProcessingAction
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
                              'Approve Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_selectedTab == 1 && _filteredDiscounts.isNotEmpty && _selectedDiscountsCount > 0)
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
                              '${_selectedDiscountsCount} discount${_selectedDiscountsCount > 1 ? 's' : ''} selected',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isApprovingDiscounts ? null : _approveSelectedDiscounts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ApprovalQueueColors.primaryDarkBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _isApprovingDiscounts
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
                              'Approve Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if ((_selectedTab == 0 && _filteredRefunds.isNotEmpty) ||
                      (_selectedTab == 1 && _filteredDiscounts.isNotEmpty))
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
                            value: _selectedTab == 0 ? _selectAll : _selectAllDiscounts,
                            onChanged: (_selectedTab == 0 && _isProcessingAction) || 
                                      (_selectedTab == 1 && _isApprovingDiscounts) 
                                ? null 
                                : _handleSelectAll,
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
                            '${_selectedTab == 0 ? _filteredRefunds.length : _filteredDiscounts.length} items',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: ApprovalQueueColors.textBodyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                
                  if (_selectedTab == 0) ...[
                    if (_isLoadingRefunds)
                      _buildCompactLoadingState()
                    else if (_filteredRefunds.isEmpty)
                      _buildCompactEmptyState()
                    else
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          ..._filteredRefunds.asMap().entries.map((entry) {
                            final index = entry.key;
                            final refund = entry.value as Map<String, dynamic>;
                            return _buildCompactRefundCard(refund, index);
                          }).toList(),
                          const SizedBox(height: 12),
                        ],
                      ),
                  ] else if (_selectedTab == 1) ...[
                    if (_isLoadingDiscounts)
                      _buildCompactLoadingState()
                    else if (_filteredDiscounts.isEmpty)
                      _buildCompactEmptyState()
                    else
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          ..._filteredDiscounts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final discount = entry.value as Map<String, dynamic>;
                            return _buildCompactDiscountCard(discount, index);
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
}

// Cancel Refund Dialog
class CancelRefundDialog extends StatefulWidget {
  final String refundId;
  final String patientName;
  final Function(String) onCancel;

  const CancelRefundDialog({
    super.key,
    required this.refundId,
    required this.patientName,
    required this.onCancel,
  });

  @override
  State<CancelRefundDialog> createState() => _CancelRefundDialogState();
}

class _CancelRefundDialogState extends State<CancelRefundDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isCancelling = false;

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
                    color: ApprovalQueueColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    color: ApprovalQueueColors.errorRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel Refund Request',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ApprovalQueueColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Refund ID: ${widget.refundId}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ApprovalQueueColors.textBodyColor,
              ),
            ),
            Text(
              'Patient: ${widget.patientName}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ApprovalQueueColors.textBodyColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please provide a reason for cancellation:',
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
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter cancellation reason...',
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
                maxLines: 3,
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
                    onPressed: _isCancelling
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
                      'Back',
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
                    onPressed: _isCancelling || _reasonController.text.trim().isEmpty
                        ? null
                        : () async {
                            setState(() {
                              _isCancelling = true;
                            });
                            
                            await widget.onCancel(_reasonController.text.trim());
                            
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ApprovalQueueColors.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Cancel Request',
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
    _reasonController.dispose();
    super.dispose();
  }
}

// Unified Approve Note Dialog
class ApproveNoteDialog extends StatefulWidget {
  final String title;
  final String itemId;
  final String patientName;
  final String type;
  final Function(String) onApprove;

  const ApproveNoteDialog({
    super.key,
    required this.title,
    required this.itemId,
    required this.patientName,
    required this.type,
    required this.onApprove,
  });

  @override
  State<ApproveNoteDialog> createState() => _ApproveNoteDialogState();
}

class _ApproveNoteDialogState extends State<ApproveNoteDialog> {
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
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ApprovalQueueColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.type == 'Refund') ...[
              Text(
                'Refund ID: ${widget.itemId}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ApprovalQueueColors.textBodyColor,
                ),
              ),
            ] else ...[
              Text(
                'Discount ID: ${widget.itemId}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ApprovalQueueColors.textBodyColor,
                ),
              ),
            ],
            if (widget.patientName != 'Bulk Approval')
              Text(
                'Patient: ${widget.patientName}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ApprovalQueueColors.textBodyColor,
                ),
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