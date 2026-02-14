import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:staff_mate/pages/submit_ticket_page.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textBodyColor = Color(0xFF4A5568);
  static const Color lightGreyColor = Color(0xFFF5F7FA);
}

class MyHRScreen extends StatefulWidget {
  final int initialSection;
  final String? openDialog;
  
  const MyHRScreen({
    super.key,
    this.initialSection = 0,
    this.openDialog,
  });

  @override
  State<MyHRScreen> createState() => _MyHRScreenState();
}

class _MyHRScreenState extends State<MyHRScreen> {
  // HR-related data
  String empId = 'EMP001';
  String department = 'Cardiology';
  String designation = 'Senior Nurse';
  String managerName = 'Dr. John Smith';
  String joiningDate = '2023-01-15';
  String employmentType = 'Full-time';
  String salaryGrade = 'Grade 7';
  String leaveBalance = '18 days';
  String performanceRating = '4.2/5.0';
  
  // Additional HR fields
  String workShift = 'Morning (9 AM - 5 PM)';
  String insuranceProvider = 'HealthCare Plus';
  String taxId = 'TAX789012';
  String pfNumber = 'PF34567890';
  String uanNumber = 'UAN1234567890';
  
  // New HR sections
  int selectedSection = 0;
  bool isLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // For expandable cards in My HR Info - CHANGED TO USE PageStorageKey
  final PageStorageKey basicInfoKey = const PageStorageKey('basic_info');
  final PageStorageKey additionalInfoKey = const PageStorageKey('additional_info');
  bool basicInfoExpanded = false;
  bool additionalInfoExpanded = false;

  // For leave management
  TextEditingController leaveReasonController = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;
  String? selectedLeaveType;
  
  // For OT/OD
  TextEditingController otReasonController = TextEditingController();
  TextEditingController odPurposeController = TextEditingController();
  DateTime? otDate;
  DateTime? odDate;
  String? selectedHours;

  // Frequently used leaves
  List<Map<String, dynamic>> frequentlyUsedLeaves = [
    {'type': 'Annual Leave', 'icon': Icons.beach_access, 'color': Colors.blue},
    {'type': 'Sick Leave', 'icon': Icons.medical_services, 'color': Colors.red},
    {'type': 'Casual Leave', 'icon': Icons.coffee, 'color': Colors.green},
    {'type': 'Maternity Leave', 'icon': Icons.child_friendly, 'color': Colors.pink},
    {'type': 'Paternity Leave', 'icon': Icons.family_restroom, 'color': Colors.cyan},
    {'type': 'Emergency Leave', 'icon': Icons.warning, 'color': Colors.orange},
  ];

  // Common OT hours suggestions
  List<String> otHoursSuggestions = ['1 hour', '2 hours', '3 hours', '4 hours', '6 hours', '8 hours'];

  // Mock data for demonstration
  List<Map<String, dynamic>> leaveHistory = [
    {'type': 'Annual Leave', 'date': '2024-01-15', 'days': 2, 'status': 'Approved'},
    {'type': 'Sick Leave', 'date': '2024-01-10', 'days': 1, 'status': 'Approved'},
    {'type': 'Casual Leave', 'date': '2023-12-20', 'days': 1, 'status': 'Approved'},
  ];

  List<Map<String, dynamic>> otHistory = [
    {'date': '2024-01-20', 'hours': 3, 'reason': 'Emergency case', 'status': 'Approved'},
    {'date': '2024-01-15', 'hours': 2, 'reason': 'Project deadline', 'status': 'Pending'},
  ];

  List<Map<String, dynamic>> attendanceHistory = [
    {'date': '2024-01-25', 'checkIn': '08:55 AM', 'checkOut': '05:10 PM', 'status': 'Present'},
    {'date': '2024-01-24', 'checkIn': '09:05 AM', 'checkOut': '05:00 PM', 'status': 'Present'},
    {'date': '2024-01-23', 'checkIn': '08:50 AM', 'checkOut': '05:15 PM', 'status': 'Present'},
  ];

  List<Map<String, dynamic>> salaryHistory = [
    {'month': 'January 2024', 'basic': '₹45,000', 'deductions': '₹8,500', 'net': '₹36,500', 'status': 'Paid'},
    {'month': 'December 2023', 'basic': '₹45,000', 'deductions': '₹8,200', 'net': '₹36,800', 'status': 'Paid'},
    {'month': 'November 2023', 'basic': '₹45,000', 'deductions': '₹8,300', 'net': '₹36,700', 'status': 'Paid'},
  ];

  @override
  void initState() {
    super.initState();
    selectedSection = widget.initialSection;
    // Open dialog if specified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openDialog != null) {
        _openDialog(widget.openDialog!);
      }
    });
  }

  void _openDialog(String dialogType) {
    switch (dialogType) {
      case 'apply_leave':
        _showApplyLeaveDialog();
        break;
      case 'apply_ot':
        _showApplyOTDialog();
        break;
      case 'apply_od':
        _showApplyODDialog();
        break;
      case 'check_in':
        _showCheckInDialog();
        break;
      case 'check_out':
        _showCheckOutDialog();
        break;
      case 'download_payslip':
        _downloadPayslip();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGreyColor,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          _buildSectionTabs(),
          Expanded(
            child: _buildCurrentSection(),
          ),
        ],
      ),
    );
  }

  // ... [Rest of your MyHRScreen code remains the same - only added the constructor parameter and initState]


  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 2,
        left: 20,
        right: 20,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryDarkBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LineIcons.bars, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Human Resources Portal",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Confidential Information",
                  style: GoogleFonts.nunito(
                    color: AppColors.lightBlue,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs() {
    List<String> sections = [
      'My HR Info',
      'Leave Management',
      'OT / OD',
      'Attendance',
      'Salary',
    ];

    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedSection = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selectedSection == index
                        ? AppColors.accentBlue
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                sections[index],
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: selectedSection == index
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: selectedSection == index
                      ? AppColors.accentBlue
                      : Colors.grey[700],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (selectedSection) {
      case 0:
        return _buildMyHRInfo();
      case 1:
        return _buildLeaveManagement();
      case 2:
        return _buildOTOD();
      case 3:
        return _buildAttendance();
      case 4:
        return _buildSalary();
      default:
        return _buildMyHRInfo();
    }
  }

  Widget _buildMyHRInfo() {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('my_hr_info'),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              key: basicInfoKey,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              initiallyExpanded: basicInfoExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  basicInfoExpanded = expanded;
                });
              },
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.accentBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Basic Information",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      _buildCompactInfoRow("Employee ID", empId, Icons.badge_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Joining Date", joiningDate, Icons.calendar_today_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Designation", designation, Icons.work_outline),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Department", department, Icons.business_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Reporting Manager", managerName, Icons.supervisor_account_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              key: additionalInfoKey,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              initiallyExpanded: additionalInfoExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  additionalInfoExpanded = expanded;
                });
              },
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Additional Information",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      _buildCompactInfoRow("Employment Type", employmentType, Icons.work_outline),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Salary Grade", salaryGrade, Icons.attach_money_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Work Shift", workShift, Icons.access_time_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Insurance Provider", insuranceProvider, Icons.health_and_safety_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("Tax ID", taxId, Icons.description_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("PF Number", pfNumber, Icons.document_scanner_outlined),
                      const SizedBox(height: 10),
                      _buildCompactInfoRow("UAN Number", uanNumber, Icons.vpn_key_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
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
                  "Leave Management",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Leave Balance Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Leave Balance",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            leaveBalance,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.beach_access_outlined,
                        color: Colors.green.shade700,
                        size: 36,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Frequently Used Leaves Section
                Text(
                  "Frequently Used Leaves",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.midDarkBlue,
                  ),
                ),
                const SizedBox(height: 10),
                
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: frequentlyUsedLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = frequentlyUsedLeaves[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLeaveType = leave['type'];
                          });
                          _showApplyLeaveDialog(initialLeaveType: leave['type']);
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: leave['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: leave['color'].withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                leave['icon'],
                                color: leave['color'],
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                leave['type'],
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: leave['color'],
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Apply Leave Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showApplyLeaveDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(
                      "Apply Leave",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // Leave History
                Text(
                  "Leave History",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.midDarkBlue,
                  ),
                ),
                const SizedBox(height: 10),
                ...leaveHistory.map((leave) => _buildLeaveHistoryCard(leave)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTOD() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
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
                  "OT / OD",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Apply OT Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showApplyOTDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(
                      "Apply OT",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                
                // Apply OD Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showApplyODDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.car_rental_outlined, size: 18),
                    label: Text(
                      "Apply OD",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                
                // View History
                Text(
                  "View History",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.midDarkBlue,
                  ),
                ),
                const SizedBox(height: 10),
                ...otHistory.map((ot) => _buildOTHistoryCard(ot)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendance() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
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
                  " Attendance",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Check-in/Check-out Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showCheckInDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(
                          "Check-in",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showCheckOutDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(
                          "Check-out",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),
                
                // Attendance History
                Text(
                  "Attendance History",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.midDarkBlue,
                  ),
                ),
                const SizedBox(height: 10),
                ...attendanceHistory
                    .map((attendance) => _buildAttendanceCard(attendance)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
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
                  "Salary",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Salary Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Current Month Salary",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.purple.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Paid",
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Basic Salary",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                "₹45,000",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.purple.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Net Salary",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                "₹36,500",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.purple.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Payslip Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _downloadPayslip();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      "Download Payslip",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // Salary History
                Text(
                  "Salary History",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.midDarkBlue,
                  ),
                ),
                const SizedBox(height: 10),
                ...salaryHistory.map((salary) => _buildSalaryHistoryCard(salary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveHistoryCard(Map<String, dynamic> leave) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: leave['status'] == 'Approved'
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.calendar_today,
              size: 14,
              color: leave['status'] == 'Approved'
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      leave['type'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: leave['status'] == 'Approved'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        leave['status'],
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: leave['status'] == 'Approved'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Date: ${leave['date']} | Days: ${leave['days']}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTHistoryCard(Map<String, dynamic> ot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ot['status'] == 'Approved'
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.timer,
              size: 14,
              color: ot['status'] == 'Approved'
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${ot['hours']} hours OT',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: ot['status'] == 'Approved'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        ot['status'],
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: ot['status'] == 'Approved'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Date: ${ot['date']}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Reason: ${ot['reason']}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> attendance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: attendance['status'] == 'Present'
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              attendance['status'] == 'Present'
                  ? Icons.check_circle
                  : Icons.cancel,
              size: 14,
              color: attendance['status'] == 'Present'
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      attendance['date'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: attendance['status'] == 'Present'
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        attendance['status'],
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: attendance['status'] == 'Present'
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.login, size: 10, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      attendance['checkIn'],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.logout, size: 10, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      attendance['checkOut'],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryHistoryCard(Map<String, dynamic> salary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.currency_rupee,
              size: 14,
              color: Colors.purple.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      salary['month'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        salary['status'],
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Basic: ${salary['basic']}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Deductions: ${salary['deductions']}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Net: ${salary['net']}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Dialog Methods
  void _showApplyLeaveDialog({String? initialLeaveType}) {
    leaveReasonController.clear();
    fromDate = null;
    toDate = null;
    selectedLeaveType = initialLeaveType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              "Apply Leave",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leave Type Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedLeaveType,
                    decoration: InputDecoration(
                      labelText: 'Leave Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: frequentlyUsedLeaves.map((leave) {
                      return DropdownMenuItem<String>(
                        value: leave['type'],
                        child: Row(
                          children: [
                            Icon(leave['icon'], color: leave['color'], size: 18),
                            const SizedBox(width: 8),
                            Text(leave['type']),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLeaveType = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // From Date with Calendar
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          fromDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.accentBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fromDate == null
                                  ? 'Select From Date'
                                  : 'From: ${fromDate!.day}/${fromDate!.month}/${fromDate!.year}',
                              style: GoogleFonts.poppins(
                                color: fromDate == null ? Colors.grey.shade600 : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // To Date with Calendar
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: fromDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          toDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.accentBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              toDate == null
                                  ? 'Select To Date'
                                  : 'To: ${toDate!.day}/${toDate!.month}/${toDate!.year}',
                              style: GoogleFonts.poppins(
                                color: toDate == null ? Colors.grey.shade600 : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Calculate days
                  if (fromDate != null && toDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Total Days: ${toDate!.difference(fromDate!).inDays + 1}',
                        style: GoogleFonts.poppins(
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Reason
                  TextField(
                    controller: leaveReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedLeaveType == null || fromDate == null || toDate == null || leaveReasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all fields',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Leave application submitted successfully!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Reset form
                  setState(() {
                    selectedLeaveType = null;
                    fromDate = null;
                    toDate = null;
                    leaveReasonController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                ),
                child: Text(
                  'Submit',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApplyOTDialog() {
    otReasonController.clear();
    otDate = null;
    selectedHours = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              "Apply Overtime",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selection with Calendar
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          otDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.orange.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              otDate == null
                                  ? 'Select Date'
                                  : 'Date: ${otDate!.day}/${otDate!.month}/${otDate!.year}',
                              style: GoogleFonts.poppins(
                                color: otDate == null ? Colors.grey.shade600 : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Hours Selection
                  Text(
                    "Select Hours:",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: otHoursSuggestions.map((hours) {
                      return ChoiceChip(
                        label: Text(hours),
                        selected: selectedHours == hours,
                        onSelected: (selected) {
                          setState(() {
                            selectedHours = selected ? hours : null;
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.orange.shade100,
                        labelStyle: GoogleFonts.poppins(
                          color: selectedHours == hours ? Colors.orange.shade800 : Colors.grey.shade700,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Custom Hours Input
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Or enter custom hours',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          selectedHours = '$value hours';
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Reason
                  TextField(
                    controller: otReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  
                  // Suggestions
                  const SizedBox(height: 8),
                  Text(
                    "Common reasons: Project deadline, Emergency case, Client meeting",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (otDate == null || selectedHours == null || otReasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all fields',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'OT application submitted successfully!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                ),
                child: Text(
                  'Submit',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApplyODDialog() {
    odPurposeController.clear();
    odDate = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              "Apply Official Duty",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selection with Calendar
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          odDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              odDate == null
                                  ? 'Select Date'
                                  : 'Date: ${odDate!.day}/${odDate!.month}/${odDate!.year}',
                              style: GoogleFonts.poppins(
                                color: odDate == null ? Colors.grey.shade600 : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Location
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: Icon(Icons.location_on, color: Colors.blue.shade600),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Purpose
                  TextField(
                    controller: odPurposeController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Purpose',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  
                  // Suggestions
                  const SizedBox(height: 8),
                  Text(
                    "Common purposes: Client meeting, Field work, Training, Conference",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (odDate == null || odPurposeController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all fields',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'OD application submitted successfully!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                ),
                child: Text(
                  'Submit',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCheckInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Check-in",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.login,
              size: 50,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 10),
            Text(
              'Check-in time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Checked-in successfully!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Check-out",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red.shade800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.logout,
              size: 50,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 10),
            Text(
              'Check-out time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Checked-out successfully!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPayslip() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payslip download started!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Drawer
  Widget _buildDrawer() {
    final size = MediaQuery.of(context).size;

    return Drawer(
      width: size.width * 0.75,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.only(top: 50, bottom: 30, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: AppColors.primaryDarkBlue,
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(40)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Icon(LineIcons.user, color: AppColors.primaryDarkBlue),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "HR Portal",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          "Human Resources",
                          style: GoogleFonts.nunito(
                              color: AppColors.lightBlue, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            "StaffMate Employee",
                            style: GoogleFonts.nunito(
                                color: Colors.white70, fontSize: 10),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                children: [
                  _drawerItem(LineIcons.pieChart, "Dashboard", () {
                    Navigator.pop(context);
                  }),
                  _drawerItem(LineIcons.paperPlane, "Submit Ticket", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SubmitTicketPage()),
                    );
                  }),
                  _drawerItem(LineIcons.history, "History", () {
                    Navigator.pop(context);
                  }),
                  ExpansionTile(
                    key: const PageStorageKey('attendance_expansion'),
                    leading: const Icon(LineIcons.calendar,
                        color: AppColors.midDarkBlue, size: 22),
                    title: Text(
                      "Attendance",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: _drawerItem(
                            LineIcons.calendarCheck, "Monthly Report", () {}),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: _drawerItem(
                            LineIcons.coffee, "Leave Requests", () {}),
                      ),
                    ],
                  ),
                  const Divider(),
                  _drawerItem(LineIcons.cog, "Settings", () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "StaffMate v1.0.0",
                style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.midDarkBlue, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: AppColors.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
      hoverColor: AppColors.lightBlue.withOpacity(0.1),
    );
  }
}