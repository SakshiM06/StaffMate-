import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textBodyColor = Color(0xFF4A5568);
  static const Color lightGreyColor = Color(0xFFF5F7FA);
  static const Color errorRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color purple = Color(0xFF9C27B0);
  static const Color pink = Color(0xFFE91E63);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFEEEEEE);
}

class RotaPage extends StatefulWidget {
  const RotaPage({Key? key}) : super(key: key);

  @override
  State<RotaPage> createState() => _RotaPageState();
}

class _RotaPageState extends State<RotaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedView = 'Weekly';
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Page storage keys for expansion tiles
  final PageStorageKey shiftDetailsKey = const PageStorageKey('shift_details');
  final PageStorageKey emergencyDetailsKey = const PageStorageKey('emergency_details');
  
  // Sample ROTA data
  final List<RotaShift> _rotaShifts = [
    RotaShift(
      staffName: 'Dr. Sarah Johnson',
      employeeId: 'DOC001',
      role: 'Doctor',
      department: 'Cardiology',
      date: DateTime.now(),
      shiftType: 'Morning',
      shiftTiming: '08:00 - 16:00',
      assignedWard: 'Ward A',
      status: ShiftStatus.ongoing,
      emergencyDuty: false,
      backupDuty: false,
      onCallStatus: false,
    ),
    RotaShift(
      staffName: 'Nurse Emily Brown',
      employeeId: 'NUR045',
      role: 'Nurse',
      department: 'Emergency',
      date: DateTime.now().add(const Duration(days: 1)),
      shiftType: 'Evening',
      shiftTiming: '16:00 - 00:00',
      assignedWard: 'ER',
      status: ShiftStatus.upcoming,
      emergencyDuty: true,
      backupDuty: true,
      onCallStatus: true,
    ),
    RotaShift(
      staffName: 'Admin Mike Wilson',
      employeeId: 'ADM012',
      role: 'Admin',
      department: 'Administration',
      date: DateTime.now().subtract(const Duration(days: 1)),
      shiftType: 'Night',
      shiftTiming: '00:00 - 08:00',
      assignedWard: 'Admin Block',
      status: ShiftStatus.completed,
      emergencyDuty: false,
      backupDuty: false,
      onCallStatus: false,
    ),
    RotaShift(
      staffName: 'Dr. James Lee',
      employeeId: 'DOC023',
      role: 'Doctor',
      department: 'Pediatrics',
      date: DateTime.now().add(const Duration(days: 2)),
      shiftType: 'Morning',
      shiftTiming: '08:00 - 16:00',
      assignedWard: 'Ward B',
      status: ShiftStatus.offDay,
      emergencyDuty: false,
      backupDuty: false,
      onCallStatus: false,
    ),
    RotaShift(
      staffName: 'Nurse Lisa Chen',
      employeeId: 'NUR078',
      role: 'Nurse',
      department: 'ICU',
      date: DateTime.now().add(const Duration(days: 3)),
      shiftType: 'Night',
      shiftTiming: '00:00 - 08:00',
      assignedWard: 'ICU',
      status: ShiftStatus.onLeave,
      emergencyDuty: false,
      backupDuty: false,
      onCallStatus: false,
    ),
  ];

  // Frequently used shift types
  List<Map<String, dynamic>> shiftTypes = [
    {'type': 'Morning', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'type': 'Evening', 'icon': Icons.nights_stay, 'color': Colors.indigo},
    {'type': 'Night', 'icon': Icons.dark_mode, 'color': Colors.deepPurple},
    {'type': 'Off Day', 'icon': Icons.beach_access, 'color': Colors.grey},
    {'type': 'On Leave', 'icon': Icons.flight, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.04;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: Text(
          'ROTA Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDarkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppColors.accentBlue,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM').format(_currentDate),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Date Range Selector
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.date_range,
                              color: AppColors.accentBlue,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getDateRangeText(),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedView,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          dropdownColor: AppColors.primaryDarkBlue,
                          items: ['Weekly', 'Monthly'].map((view) {
                            return DropdownMenuItem(
                              value: view,
                              child: Text(view),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedView = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: AppColors.accentBlue,
                    shape: BoxShape.rectangle,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: 'Shifts'),
                    Tab(text: 'Status'),
                    Tab(text: 'Emergency'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDarkBlue),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildShiftInformationTab(),
                _buildShiftStatusTab(),
                _buildEmergencyInfoTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _downloadROTA,
        backgroundColor: AppColors.accentBlue,
        child: const Icon(Icons.download, color: Colors.white),
      ),
    );
  }

  // Tab 1: Basic Shift Information
  Widget _buildShiftInformationTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rotaShifts.length,
      itemBuilder: (context, index) {
        final shift = _rotaShifts[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: PageStorageKey('shift_$index'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getRoleColor(shift.role).withOpacity(0.8),
                            _getRoleColor(shift.role),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          shift.role.substring(0, 1),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      shift.staffName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.employeeId,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(shift.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(shift.status),
                                    size: 10,
                                    color: _getStatusColor(shift.status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getStatusText(shift.status),
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: _getStatusColor(shift.status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreyColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.primaryDarkBlue,
                        size: 18,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreyColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.person_outline,
                              'Role',
                              shift.role,
                              AppColors.infoBlue,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              'Department',
                              shift.department,
                              AppColors.purple,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              'Date',
                              _formatDate(shift.date),
                              AppColors.accentBlue,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.access_time_outlined,
                              'Shift',
                              '${shift.shiftType} (${shift.shiftTiming})',
                              AppColors.warningOrange,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.place_outlined,
                              'Ward',
                              shift.assignedWard,
                              AppColors.successGreen,
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
        );
      },
    );
  }

  // Tab 2: Shift Status
  Widget _buildShiftStatusTab() {
    // Calculate counts
    int upcoming = _rotaShifts.where((s) => s.status == ShiftStatus.upcoming).length;
    int ongoing = _rotaShifts.where((s) => s.status == ShiftStatus.ongoing).length;
    int completed = _rotaShifts.where((s) => s.status == ShiftStatus.completed).length;
    int offDay = _rotaShifts.where((s) => s.status == ShiftStatus.offDay).length;
    int onLeave = _rotaShifts.where((s) => s.status == ShiftStatus.onLeave).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pie_chart_outline,
                        color: AppColors.accentBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Status Overview",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusIndicator(upcoming, "Upcoming", AppColors.infoBlue),
                    _buildStatusIndicator(ongoing, "Ongoing", AppColors.successGreen),
                    _buildStatusIndicator(completed, "Completed", AppColors.warningOrange),
                    _buildStatusIndicator(offDay, "Off Day", AppColors.textBodyColor),
                    _buildStatusIndicator(onLeave, "On Leave", AppColors.purple),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status Details',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreyColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_rotaShifts.length} Total',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textBodyColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                ..._rotaShifts.map((shift) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreyColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getStatusColor(shift.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _getStatusIcon(shift.status),
                            color: _getStatusColor(shift.status),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.staffName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  shift.role,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.textBodyColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppColors.textBodyColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(shift.date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.textBodyColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(shift.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(shift.status),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(shift.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 3: Emergency Assignment Info
  Widget _buildEmergencyInfoTab() {
    final emergencyShifts = _rotaShifts.where((s) => s.emergencyDuty || s.backupDuty || s.onCallStatus).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Emergency Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.errorRed, AppColors.errorRed.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.errorRed.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Emergency Status",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${emergencyShifts.length} Active',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildEmergencyStatItem(
                      'Emergency',
                      _rotaShifts.where((s) => s.emergencyDuty).length,
                      Icons.warning,
                    ),
                    _buildEmergencyStatItem(
                      'Backup',
                      _rotaShifts.where((s) => s.backupDuty).length,
                      Icons.backup,
                    ),
                    _buildEmergencyStatItem(
                      'On-Call',
                      _rotaShifts.where((s) => s.onCallStatus).length,
                      Icons.phone_in_talk,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Emergency Assignments List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Assignments',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (emergencyShifts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 50,
                            color: AppColors.successGreen.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Emergency Assignments',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textBodyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...emergencyShifts.map((shift) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreyColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getEmergencyColor(shift).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getEmergencyColor(shift).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              _getEmergencyIcon(shift),
                              color: _getEmergencyColor(shift),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.staffName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${shift.role} • ${shift.department}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.textBodyColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (shift.emergencyDuty)
                                    _buildEmergencyTag('Emergency', AppColors.errorRed),
                                  if (shift.backupDuty)
                                    _buildEmergencyTag('Backup', AppColors.warningOrange),
                                  if (shift.onCallStatus)
                                    _buildEmergencyTag('On-Call', AppColors.infoBlue),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatTime(shift.date),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textBodyColor,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: AppColors.textBodyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // Helper Methods for Actions
  void _showDatePicker() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDarkBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _currentDate) {
      setState(() {
        _currentDate = picked;
      });
    }
  }

  void _downloadROTA() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.download_done,
              size: 60,
              color: AppColors.successGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'Download Started',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ROTA PDF is being generated',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textBodyColor,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods for Formatting
  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  String _getDateRangeText() {
    if (_selectedView == 'Weekly') {
      final start = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
    } else {
      return DateFormat('MMMM yyyy').format(_currentDate);
    }
  }

  // Color Helper Methods
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return AppColors.infoBlue;
      case 'nurse':
        return AppColors.successGreen;
      case 'admin':
        return AppColors.warningOrange;
      default:
        return AppColors.textBodyColor;
    }
  }

  Color _getStatusColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.upcoming:
        return AppColors.infoBlue;
      case ShiftStatus.ongoing:
        return AppColors.successGreen;
      case ShiftStatus.completed:
        return AppColors.warningOrange;
      case ShiftStatus.offDay:
        return AppColors.textBodyColor;
      case ShiftStatus.onLeave:
        return AppColors.purple;
    }
  }

  IconData _getStatusIcon(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.upcoming:
        return Icons.schedule_outlined;
      case ShiftStatus.ongoing:
        return Icons.play_circle_outline;
      case ShiftStatus.completed:
        return Icons.check_circle_outline;
      case ShiftStatus.offDay:
        return Icons.beach_access_outlined;
      case ShiftStatus.onLeave:
        return Icons.flight_takeoff_outlined;
    }
  }

  String _getStatusText(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.upcoming:
        return 'Upcoming';
      case ShiftStatus.ongoing:
        return 'Ongoing';
      case ShiftStatus.completed:
        return 'Completed';
      case ShiftStatus.offDay:
        return 'Off Day';
      case ShiftStatus.onLeave:
        return 'On Leave';
    }
  }

  Color _getEmergencyColor(RotaShift shift) {
    if (shift.emergencyDuty) return AppColors.errorRed;
    if (shift.backupDuty) return AppColors.warningOrange;
    return AppColors.infoBlue;
  }

  IconData _getEmergencyIcon(RotaShift shift) {
    if (shift.emergencyDuty) return Icons.warning;
    if (shift.backupDuty) return Icons.backup;
    return Icons.phone_in_talk;
  }
}

// Model Classes
enum ShiftStatus {
  upcoming,
  ongoing,
  completed,
  offDay,
  onLeave,
}

class RotaShift {
  final String staffName;
  final String employeeId;
  final String role;
  final String department;
  final DateTime date;
  final String shiftType;
  final String shiftTiming;
  final String assignedWard;
  final ShiftStatus status;
  final bool emergencyDuty;
  final bool backupDuty;
  final bool onCallStatus;

  RotaShift({
    required this.staffName,
    required this.employeeId,
    required this.role,
    required this.department,
    required this.date,
    required this.shiftType,
    required this.shiftTiming,
    required this.assignedWard,
    required this.status,
    required this.emergencyDuty,
    required this.backupDuty,
    required this.onCallStatus,
  });
}