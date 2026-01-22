import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/services/notification_service.dart';

class NotificationDetailsPage extends StatefulWidget {
  final String patientName;
  final String patientId;
  final String admissionId;

  const NotificationDetailsPage({
    super.key,
    required this.patientName,
    required this.patientId,
    required this.admissionId,
  });

  @override
  State<NotificationDetailsPage> createState() => _NotificationDetailsPageState();
}

class _NotificationDetailsPageState extends State<NotificationDetailsPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final String _todayDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());
  final IpdService _ipdService = IpdService();

  // API Data States
  bool _isLoading = false;
  bool _isInvestigationLoading = false;
  String _errorMessage = '';
  String _investigationErrorMessage = '';
  
  List<Map<String, dynamic>> _prescriptions = [];
  final List<Map<String, dynamic>> _nursingTasks = [
    {"task": "Check Vitals", "freq": "Every 4 Hours", "confirmed": false},
    {"task": "Sponge Bath", "freq": "Once a day", "confirmed": true},
  ];
  List<Map<String, dynamic>> _investigations = [];

  bool _prescriptionLoaded = false;
  bool _investigationLoaded = false;

  // Refresh tracking
  bool _showRefreshBadge = false;
  DateTime? _lastRefreshTime;

  final Color darkBlue = const Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color borderGrey = const Color(0xFFE0E0E0);
  final Color cardBlue = const Color(0xFFE8EAF6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadPrescriptionData();
    
    // Check for recent saves after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkForRecentSaves();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for updates when app comes back to foreground
      _checkForRecentSaves();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for updates when page becomes visible again
    _checkForRecentSaves();
  }

  // Future<void> _checkForRecentSaves() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final lastSaveTimeStr = prefs.getString('last_investigation_save_time');
  //     final shouldRefreshFlag = prefs.getBool('shouldRefreshNotifications') ?? false;
      
  //     bool shouldRefresh = false;
      
  //     // Check timestamp
  //     if (lastSaveTimeStr != null) {
  //       final lastSaveTime = DateTime.parse(lastSaveTimeStr);
  //       final now = DateTime.now();
  //       final difference = now.difference(lastSaveTime).inMinutes;
        
  //       if (difference < 10) { // Saved within last 10 minutes
  //         await prefs.remove('last_investigation_save_time');
  //         shouldRefresh = true;
  //       }
  //     }
      
  //     // Check flag
  //     if (shouldRefreshFlag) {
  //       await prefs.remove('shouldRefreshNotifications');
  //       shouldRefresh = true;
  //     }
      
  //     if (shouldRefresh && mounted) {
  //       setState(() {
  //         _showRefreshBadge = true;
  //       });
        
  //       // Show snackbar notification
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: const Text('New data available. Tap refresh to update.'),
  //             backgroundColor: Colors.green,
  //             duration: const Duration(seconds: 3),
  //             behavior: SnackBarBehavior.floating,
  //           ),
  //         );
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint('Error checking recent saves: $e');
  //   }
  // }

// Update _checkForRecentSaves method:
Future<void> _checkForRecentSaves() async {
  try {
    final shouldRefresh = await NotificationRefreshService().shouldRefresh();
    
    if (shouldRefresh && mounted) {
      setState(() {
        _showRefreshBadge = true;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('New data available. Tap refresh to update.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  } catch (e) {
    debugPrint('Error checking recent saves: $e');
  }
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final currentIndex = _tabController.index;
      if (_showRefreshBadge) {
        setState(() {
          _showRefreshBadge = false;
        });
        
        if (currentIndex == 0) {
          setState(() {
            _prescriptionLoaded = false;
          });
          _loadPrescriptionData();
        } else if (currentIndex == 2) {
          setState(() {
            _investigationLoaded = false;
          });
          _loadInvestigationData();
        }
      } else {
        if (currentIndex == 2 && !_investigationLoaded) {
          _loadInvestigationData();
        } else if (currentIndex == 0 && !_prescriptionLoaded) {
          _loadPrescriptionData();
        }
      }
    }
  }

  Future<void> _loadPrescriptionData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    String admissionIdToUse = widget.admissionId;
    
    // debugPrint('🔍 NotificationDetailsPage - Loading prescriptions');
    // debugPrint('📋 Received admissionId from widget: ${widget.admissionId}');
    // debugPrint('📋 Received patientName: ${widget.patientName}');
    // debugPrint('📋 Received patientId: ${widget.patientId}');

    // Use the admission ID from widget (should be correct)
    if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
      debugPrint('⚠️ Warning: Empty admission ID from widget');
      
      final prefs = await SharedPreferences.getInstance();
      admissionIdToUse = prefs.getString('admissionid') ?? '';
      debugPrint('📋 Using admission ID from prefs: $admissionIdToUse');
      
      if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
        throw Exception('No valid admission ID found. Please select a patient first.');
      }
    }
    
    debugPrint('🚀 Fetching prescriptions for admission: $admissionIdToUse');
    
    final response = await _ipdService.fetchPrescriptionNotifications(admissionIdToUse);
    
    debugPrint('📦 API Response success: ${response['success']}');
    debugPrint('📦 API Response keys: ${response.keys}');

    if (response['success'] == true || response['status_code'] == 200) {
      final apiData = response['data'] ?? [];
      debugPrint('✅ Found ${apiData.length} prescription items');
      
      if (apiData.isNotEmpty) {
        for (var i = 0; i < apiData.length; i++) {
          final item = apiData[i];
          // debugPrint('📄 Item $i - priscriptionId: ${item['priscriptionId']}');
          // debugPrint('📄 Item $i - medicineName: ${item['priscriptiontimeName']}');
          // debugPrint('📄 Item $i - dose: ${item['dosage']}');
        }
      }
      
      setState(() {
        _prescriptions = _transformPrescriptionData(apiData);
        _prescriptionLoaded = true;
        _lastRefreshTime = DateTime.now();
        _showRefreshBadge = false; 
      });
      
      debugPrint('🔄 UI Updated with ${_prescriptions.length} prescriptions');
      await NotificationRefreshService().clearRefreshFlags();
      
    } else {
      final errorMsg = response['message'] ?? 'Failed to load prescription data';
      debugPrint('❌ API Error: $errorMsg');
      setState(() {
        _errorMessage = errorMsg;
      });
    }
  } catch (e) {
    debugPrint('❌ Exception loading prescription data: $e');
    setState(() {
      _errorMessage = 'Error: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  // Future<void> _loadPrescriptionData() async {
  //   setState(() {
  //     _isLoading = true;
  //     _errorMessage = '';
  //   });

  //   try {
  //     String admissionIdToUse = widget.admissionId;
      
  //     if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
  //       final prefs = await SharedPreferences.getInstance();
  //       admissionIdToUse = prefs.getString('admissionid') ?? '';
        
  //       if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
  //         throw Exception('No valid admission ID found. Please select a patient first.');
  //       }
  //     }
      
  //     final response = await _ipdService.fetchPrescriptionNotifications(admissionIdToUse);
      
  //     if (response['success'] == true) {
  //       final apiData = response['data'] ?? [];
  //       setState(() {
  //         _prescriptions = _transformPrescriptionData(apiData);
  //         _prescriptionLoaded = true;
  //         _lastRefreshTime = DateTime.now();
  //       });
  //     } else {
  //       setState(() {
  //         _errorMessage = response['message'] ?? 'Failed to load prescription data';
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _errorMessage = 'Error: $e';
  //     });
  //     debugPrint('Error loading prescription data: $e');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _loadInvestigationData() async {
    setState(() {
      _isInvestigationLoading = true;
      _investigationErrorMessage = '';
    });

    try {
      String admissionIdToUse = widget.admissionId;
      
      if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
        final prefs = await SharedPreferences.getInstance();
        admissionIdToUse = prefs.getString('admissionid') ?? '';
        
        if (admissionIdToUse.isEmpty || admissionIdToUse == "0") {
          throw Exception('No valid admission ID found. Please select a patient first.');
        }
      }
  
      final response = await _ipdService.fetchInvestigationNotifications(admissionIdToUse);
      
      if (response['success'] == true) {
        final apiData = response['data'] ?? [];
        
        setState(() {
          _investigations = _transformInvestigationData(apiData);
          _investigationLoaded = true;
          _lastRefreshTime = DateTime.now();
        });
      } else {
        setState(() {
          _investigationErrorMessage = response['message'] ?? 'Failed to load investigation data';
        });
      }
    } catch (e) {
      setState(() {
        _investigationErrorMessage = 'Error: $e';
      });
      debugPrint('Error loading investigation data: $e');
    } finally {
      setState(() {
        _isInvestigationLoading = false;
      });
    }
  }

  // void _forceRefreshCurrentTab() {
  //   if (_tabController.index == 0) {
  //     setState(() {
  //       _prescriptionLoaded = false;
  //       _isLoading = true;
  //     });
  //     _loadPrescriptionData();
  //   } else if (_tabController.index == 2) {
  //     setState(() {
  //       _investigationLoaded = false;
  //       _isInvestigationLoading = true;
  //     });
  //     _loadInvestigationData();
  //   }
    
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('Refreshing data...'),
  //       backgroundColor: Colors.blue,
  //       duration: Duration(seconds: 1),
  //     ),
  //   );
  // }


  void _forceRefreshCurrentTab() {
  NotificationRefreshService().clearRefreshFlags();
  
  if (_tabController.index == 0) {
    setState(() {
      _prescriptionLoaded = false;
      _isLoading = true;
      _showRefreshBadge = false;
    });
    _loadPrescriptionData();
  } else if (_tabController.index == 2) {
    setState(() {
      _investigationLoaded = false;
      _isInvestigationLoading = true;
      _showRefreshBadge = false;
    });
    _loadInvestigationData();
  }
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Refreshing data...'),
      backgroundColor: Colors.blue,
      duration: Duration(seconds: 1),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notification Details", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text(widget.patientName, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          if (_isLoading && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _forceRefreshCurrentTab,
                tooltip: 'Refresh',
              ),
              if (_showRefreshBadge)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(55),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: darkBlue,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: "Prescription"),
                Tab(text: "Nursing"),
                Tab(text: "Investigation"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrescriptionTab(),
          _buildNursingTab(),
          _buildInvestigationTab(),
        ],
      ),
    );
  }

  Widget _buildPrescriptionTab() {
    if (_isLoading) {
      return _buildLoadingState('Loading prescription data...');
    }
    
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState(_errorMessage, _loadPrescriptionData);
    }
    
    final activePrescriptions = _prescriptions.where((item) => !item['isStopped']).toList();
    
    if (activePrescriptions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPrescriptionData,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No Active Prescriptions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Pull down to refresh',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPrescriptionData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 20),
        itemCount: activePrescriptions.length,
        itemBuilder: (context, index) {
          final item = activePrescriptions[index];
          List<String> freqParts = item['frequency'].toString().split('-');
          int originalIndex = _prescriptions.indexWhere((med) => med['id'] == item['id']);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                dense: true,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['medicine'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _handleStopMedicine(originalIndex),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stop_circle_outlined, size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              "Stop",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniDetail("Dosage", item['dosage']),
                            _buildMiniDetail("Route", item['route']),
                            _buildMiniDetail("Freq", item['frequency']),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if(item['instruction'] != "")
                          Text("Note: ${item['instruction']}", style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange[800])),
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 10),
                        Text("Today's Doses:", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 5),
                        Column(
                          children: List.generate(freqParts.length, (i) {
                            bool isScheduled = freqParts[i].trim() != "0";
                            bool isGiven = item['doseStatus'][i] == 1;
                            String remark = item['remarks'][i];
                            
                            if (!isScheduled) return const SizedBox.shrink();
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "${_getTimeLabel(i)}:",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700]
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 24,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: InkWell(
                                          onTap: () => _handleDoseClick(originalIndex, i),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: isGiven ? Colors.green : Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isGiven ? Colors.green : Colors.grey[400]!,
                                                width: 1.2
                                              )
                                            ),
                                            child: isGiven
                                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                                              : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: isGiven && remark.isNotEmpty
                                          ? Container(
                                              constraints: BoxConstraints(minHeight: 20),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.blue[100]!, width: 0.5),
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  remark,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: darkBlue,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                          : !isGiven
                                            ? Container(
                                                constraints: BoxConstraints(minHeight: 20),
                                                padding: const EdgeInsets.only(top: 3),
                                                child: Text(
                                                  "Click to confirm dose",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.grey[500],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(height: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
        Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  String _getTimeLabel(int index) {
    switch (index) {
      case 0: return "Morning";
      case 1: return "Noon";
      case 2: return "Night";
      case 3: return "Mid";
      default: return "";
    }
  }

  Widget _buildNursingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _nursingTasks.length,
      itemBuilder: (context, index) {
        final task = _nursingTasks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task['task'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text("Freq: ${task['freq']}", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: task['confirmed'],
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() => task['confirmed'] = val);
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvestigationTab() {
    if (_isInvestigationLoading) {
      return _buildLoadingState('Loading investigation data...');
    }
    
    if (_investigationErrorMessage.isNotEmpty) {
      return _buildErrorState(_investigationErrorMessage, _loadInvestigationData);
    }
    
    if (_investigations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInvestigationData,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No Investigation Data',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Pull down to refresh',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadInvestigationData,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: _investigations.length,
          itemBuilder: (context, index) {
            final inv = _investigations[index];
            bool isToday = _isToday(inv['date']);
            Color statusColor = _getStatusColor(inv['report_status']);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderGrey.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  dense: true,
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: cardBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            "${inv['sr']}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: darkBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv['type'],
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: isToday ? Colors.green[700] : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      inv['date'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isToday ? Colors.green[700] : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        inv['report_status'].toLowerCase() == 'collect' ? Icons.inventory_2 :
                                        inv['report_status'].toLowerCase() == 'completed' ? Icons.check_circle :
                                        inv['report_status'].toLowerCase() == 'approved' ? Icons.verified : Icons.pending,
                                        size: 10,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        inv['report_status'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {
                                    print("Printing ${inv['type']}");
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: darkBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: darkBlue.withOpacity(0.3), width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.print,
                                          size: 12,
                                          color: darkBlue,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          "Print",
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: darkBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[100]!, width: 1),
                          ),
                          child: Text(
                            "Today",
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniDetailInvestigation("Requested by", inv['requested_by']),
                              _buildMiniDetailInvestigation("Doctor", inv['practitioner_name']),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniDetailInvestigation("Request Date", _formatDisplayDate(inv['request_date'])),
                              if (inv['charge_status'] != null && inv['charge_status'].toString().isNotEmpty)
                                _buildMiniDetailInvestigation("Charge Status", inv['charge_status']),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (inv['uhid'] != null && inv['uhid'].toString().isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 1, thickness: 0.5),
                                const SizedBox(height: 10),
                                Text(
                                  "Patient UHID: ${inv['uhid']}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMiniDetailInvestigation(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: darkBlue),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(color: darkBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage, VoidCallback retryCallback) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: retryCallback,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDisplayDate(String? apiDate) {
    if (apiDate == null || apiDate.isEmpty) return 'N/A';
    
    try {
      final parts = apiDate.split(' ');
      if (parts.isNotEmpty) {
        final dateParts = parts[0].split('-');
        if (dateParts.length == 3) {
          return '${dateParts[0]}-${dateParts[1]}-${dateParts[2]} ${parts.length > 1 ? parts[1] : ""}';
        }
      }
      return apiDate;
    } catch (e) {
      return apiDate;
    }
  }

  // Helper methods (keep your existing implementations)
  List<Map<String, dynamic>> _transformPrescriptionData(List<dynamic> apiData) {
    List<Map<String, dynamic>> transformedData = [];
    
    for (var i = 0; i < apiData.length; i++) {
      var item = apiData[i];
      
      String medicineName = item['priscriptiontimeName']?.toString() ?? 
                           item['medicineName']?.toString() ?? 
                           'Unknown Medicine';
      
      String dosage = '500mg';
      if (item['dosage'] != null && item['dosage'].toString().isNotEmpty) {
        String dosageStr = item['dosage'].toString();
        if (dosageStr.contains(RegExp(r'\d'))) {
          dosage = dosageStr;
        }
      }
      
      String route = item['doseNotes']?.toString() ?? 'Oral';
      String frequency = _extractFrequency(item['dosage']?.toString()) ?? '1-1-0';
      List<int> doseStatus = _initializeDoseStatus(frequency);
      List<String> remarks = _initializeRemarks(frequency);
     
      if (item['dosageList'] != null && item['dosageList'] is List) {
        List<dynamic> dosageList = item['dosageList'];
        for (var dose in dosageList) {
          if (dose is Map<String, dynamic>) {
            int doseNumber = dose['doseNumber'] ?? 1;
            bool flag = dose['flag'] ?? false;
            if (doseNumber >= 1 && doseNumber <= doseStatus.length) {
              doseStatus[doseNumber - 1] = flag ? 1 : 0;
              remarks[doseNumber - 1] = dose['remark']?.toString() ?? '';
            }
          }
        }
      }
      
      transformedData.add({
        "id": item['priscriptionId'] ?? i + 100,
        "medicine": medicineName,
        "generic": item['priscriptionIndividualRemark']?.toString() ?? medicineName,
        "dosage": dosage,
        "route": route,
        "frequency": frequency,
        "instruction": item['priscriptionIndividualRemark']?.toString() ?? "After Food",
        "isStopped": false,
        "doseStatus": doseStatus,
        "remarks": remarks,
        "apiData": item,
      });
    }
    
    return transformedData;
  }

  String? _extractFrequency(String? dosage) {
    if (dosage == null) return null;
  
    if (dosage.contains('-')) {
      List<String> parts = dosage.split('-');
      if (parts.length >= 3) {
        bool isValid = true;
        for (var part in parts) {
          if (part != '0' && part != '1') {
            isValid = false;
            break;
          }
        }
        if (isValid) {
          return dosage;
        }
      }
    }
    return null;
  }

  List<int> _initializeDoseStatus(String frequency) {
    List<String> parts = frequency.split('-');
    return List<int>.generate(parts.length, (index) => 0);
  }

  List<String> _initializeRemarks(String frequency) {
    List<String> parts = frequency.split('-');
    return List<String>.generate(parts.length, (index) => "");
  }

  List<Map<String, dynamic>> _transformInvestigationData(List<dynamic> apiData) {
    List<Map<String, dynamic>> transformedData = [];
    int srCounter = 1;
    
    for (var i = 0; i < apiData.length; i++) {
      var item = apiData[i];
      
      String testName = item['test_name']?.toString() ?? 'Unknown Test';
      String requestDate = item['request_date']?.toString() ?? '';
      String formattedDate = _formatInvestigationDate(requestDate);    
      String reportStatus = item['report_status']?.toString() ?? 'Pending';
      String requestedBy = item['requested_by']?.toString() ?? 'N/A';
      String practitionerName = item['practitionnername']?.toString() ?? 'N/A';
      
      transformedData.add({
        "sr": srCounter++,
        "type": testName,
        "date": formattedDate,
        "isDeleted": false,
        "report_status": reportStatus,
        "request_date": requestDate,
        "requested_by": requestedBy,
        "practitioner_name": practitionerName,
        "charge_status": item['charge_status']?.toString() ?? '',
        "patient_name": item['patientname']?.toString() ?? '',
        "uhid": item['uhid']?.toString() ?? '',
        "apiData": item,
      });
    }
  
    transformedData.sort((a, b) => b['date'].compareTo(a['date']));
    
    return transformedData;
  }

  String _formatInvestigationDate(String? apiDate) {
    if (apiDate == null || apiDate.isEmpty) return DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    try {
      final parts = apiDate.split(' ');
      if (parts.isNotEmpty) {
        final dateParts = parts[0].split('-');
        if (dateParts.length == 3) {
          return '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';
        }
      }
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  bool _isToday(String dateStr) {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return dateStr == today;
    } catch (e) {
      return false;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'collect':
        return Colors.lightBlue;
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.brown;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _handleDoseClick(int medicineIndex, int doseIndex) {
    final medicine = _prescriptions[medicineIndex];
    
    if (medicine['doseStatus'][doseIndex] == 1) {
      return; 
    }

    TextEditingController remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Add Remark", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Medicine: ${medicine['medicine']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: remarkController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Enter note...",
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: darkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              setState(() {
                _prescriptions[medicineIndex]['doseStatus'][doseIndex] = 1;
                _prescriptions[medicineIndex]['remarks'][doseIndex] = remarkController.text;
              });
              Navigator.pop(context);
            },
            child: Text("Confirm", style: GoogleFonts.poppins(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _handleStopMedicine(int medicineIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Stop Medicine", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to stop ${_prescriptions[medicineIndex]['medicine']}?",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () {
              setState(() {
                _prescriptions[medicineIndex]['isStopped'] = true;
              });
              Navigator.pop(context);
            },
            child: Text("Stop", style: GoogleFonts.poppins(color: Colors.white)),
          )
        ],
      ),
    );
  }
}