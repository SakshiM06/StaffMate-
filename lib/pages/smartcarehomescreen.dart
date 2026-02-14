import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/profile_page.dart'; 
import 'package:staff_mate/pages/submit_ticket_page.dart'; 
import 'package:staff_mate/pages/settings.dart';
import 'package:staff_mate/services/user_information_service.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/pages/my_hr_screen.dart';
import 'package:staff_mate/pages/forget_password.dart';
import 'package:staff_mate/services/home_service.dart'; 
import 'package:staff_mate/models/staff_dob.dart';

class AppColors {
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
  static const Color drawerBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color menuItemHover = Color(0xFFE3F2FD);
  static const Color dividerColor = Color(0xFFEEEEEE);
  static const Color iconBlue = Color(0xFF1976D2);
  static const Color iconGreen = Color(0xFF388E3C);
  static const Color iconOrange = Color(0xFFF57C00);
  static const Color iconPurple = Color(0xFF7B1FA2);
}

class SmartCareHomeScreen extends StatefulWidget {
  const SmartCareHomeScreen({super.key});

  @override
  State<SmartCareHomeScreen> createState() => _SmartCareHomeScreenState();
}

class _SmartCareHomeScreenState extends State<SmartCareHomeScreen> {
  String fullName = 'Dr. Staff Member';
  String userId = '';
  String clinicName = 'Smart Care Hospital';
  String userRole = 'Medical Staff';
  String email = '';
  String phoneNumber = '';
  String address = '';
  String accessGroup = 'Admin Staff';
  String location = 'Main Hospital - Floor 3';
  
  bool isLoading = true;
  bool _isLoggingOut = false; 
  bool _loadingBirthdays = true;
  String currentDate = '';
  
  List<StaffDOB> todayBirthdays = []; 
  List<Birthday> upcomingBirthdays = [];
  List<Training> trainings = [];
  List<RotaShift> rotaShifts = [];
  List<QuickTask> quickTasks = [];
  List<PendingApproval> pendingApprovals = [];
  CheckInOutStatus checkInOutStatus = CheckInOutStatus();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setCurrentDate();
    _loadSampleData();
    _loadTodayBirthdays();
  }

  void _setCurrentDate() {
    final now = DateTime.now();
    currentDate = DateFormat('dd-MM-yyyy').format(now);
  }

  void _loadSampleData() {
    trainings = [
      Training(title: 'Advanced Life Support', date: 'Mar 15, 2024', status: 'Upcoming'),
      Training(title: 'HIPAA Compliance', date: 'Mar 20, 2024', status: 'Mandatory'),
      Training(title: 'New Equipment Training', date: 'Mar 25, 2024', status: 'Optional'),
      Training(title: 'Emergency Response', date: 'Mar 30, 2024', status: 'Mandatory'),
    ];

    rotaShifts = [
      RotaShift(date: 'Today', shift: 'Morning (7 AM - 3 PM)', location: 'Main Ward'),
      RotaShift(date: 'Tomorrow', shift: 'Evening (3 PM - 11 PM)', location: 'Emergency'),
      RotaShift(date: 'Mar 14', shift: 'Night (11 PM - 7 AM)', location: 'ICU'),
      RotaShift(date: 'Mar 15', shift: 'Morning (7 AM - 3 PM)', location: 'OPD'),
    ];

    quickTasks = [
      QuickTask(title: 'Patient Rounds', priority: 'High', time: '9:00 AM', completed: false),
      QuickTask(title: 'Documentation', priority: 'Medium', time: '2:00 PM', completed: false),
      QuickTask(title: 'Team Meeting', priority: 'Low', time: '4:00 PM', completed: true),
      QuickTask(title: 'Lab Reports Review', priority: 'High', time: '11:00 AM', completed: false),
    ];

    pendingApprovals = [
      PendingApproval(type: 'Leave Request', name: 'Dr. Lisa Park', days: '3 days', status: 'Pending'),
      PendingApproval(type: 'Overtime', name: 'Nurse John Doe', hours: '4 hours', status: 'Pending'),
      PendingApproval(type: 'Supply Order', name: 'Admin Team', items: '5 items', status: 'Pending'),
      PendingApproval(type: 'Conference', name: 'Dr. Smith', days: '2 days', status: 'Pending'),
    ];

    checkInOutStatus = CheckInOutStatus(
      checkedIn: true,
      checkInTime: '07:30 AM',
      location: 'Main Hospital',
      totalHours: '8.5',
    );

    upcomingBirthdays = [
      Birthday(name: 'Dr. Sarah Johnson', department: 'Cardiology', time: 'Today'),
      Birthday(name: 'Nurse Michael Chen', department: 'ICU', time: 'Tomorrow'),
      Birthday(name: 'Dr. Robert Wilson', department: 'Orthopedics', time: 'In 2 days'),
      Birthday(name: 'Nurse Lisa Park', department: 'Pediatrics', time: 'In 3 days'),
    ];
  }

Future<void> _loadTodayBirthdays() async {
  if (mounted) {
    setState(() {
      _loadingBirthdays = true;
      todayBirthdays.clear();
    });
  }
  
  try {
    final today = DateTime.now();
    final dobString = _formatDateForAPI(today);
    
    debugPrint('=== LOADING STAFF BIRTHDAYS ===');
    debugPrint('Current date (local): ${today.toString()}');
    debugPrint('Current date (UTC): ${today.toUtc().toString()}');
    debugPrint('Formatted for API: $dobString');
    
    final response = await HomeService.getStaffByDob(dobString);
    
    debugPrint('=== API RESPONSE ===');
    debugPrint('Response type: ${response.runtimeType}');
    debugPrint('Response keys: ${response.keys}');
    debugPrint('Full Response: $response');
    
    if (response.containsKey('data')) {
      final data = response['data'];
      debugPrint('Data type: ${data.runtimeType}');
      debugPrint('Data value: $data');
      
      if (data is List) {
        debugPrint('Data is List, length: ${data.length}');
        
        if (data.isNotEmpty) {
          debugPrint('Found ${data.length} staff with birthday today');
          
          // Print each item in the list
          for (int i = 0; i < data.length; i++) {
            debugPrint('Item $i: ${data[i]}');
            debugPrint('Item $i type: ${data[i].runtimeType}');
            
            if (data[i] is Map) {
              final Map<String, dynamic> staffData;
              if (data[i] is Map<String, dynamic>) {
                staffData = data[i] as Map<String, dynamic>;
              } else {
                // Convert from Map<dynamic, dynamic> to Map<String, dynamic>
                staffData = {};
                (data[i] as Map).forEach((key, value) {
                  staffData[key.toString()] = value;
                });
              }
              
              debugPrint('Staff $i data keys: ${staffData.keys}');
              debugPrint('Staff $i data values: ${staffData.values}');
              
              try {
                final staff = StaffDOB.fromApiResponse(staffData);
                todayBirthdays.add(staff);
                debugPrint('Successfully added: ${staff.fullName}');
                debugPrint('Full Name: ${staff.fullName}');
                debugPrint('Initial: ${staff.initial}');
                debugPrint('DOB: ${staff.dob}');
              } catch (e) {
                debugPrint('Error parsing staff $i: $e');
                debugPrint('Raw staff data: $staffData');
              }
            } else {
              debugPrint('Item $i is not a Map, it\'s: ${data[i].runtimeType}');
            }
          }
        } else {
          debugPrint('No birthday data found - empty list returned from API');
        }
      } else {
        debugPrint('Data is not a List, it\'s: ${data.runtimeType}');
      }
    } else {
      debugPrint('No "data" key in response');
      debugPrint('Available keys: ${response.keys}');
    }
    
    if (mounted) {
      setState(() {
        _loadingBirthdays = false;
      });
    }
    
    if (todayBirthdays.isNotEmpty) {
      debugPrint('=== BIRTHDAYS LOADED SUCCESSFULLY ===');
      debugPrint('Total birthdays found: ${todayBirthdays.length}');
      for (final staff in todayBirthdays) {
        debugPrint('- ${staff.fullName}');
      }
    } else {
      debugPrint('=== NO BIRTHDAYS FOUND ===');
      debugPrint('API returned empty data array');
    }
  } catch (e) {
    debugPrint('=== ERROR LOADING BIRTHDAYS ===');
    debugPrint('Error type: ${e.runtimeType}');
    debugPrint('Error message: $e');
    debugPrint('Stack trace: ${e.toString()}');
    
    if (mounted) {
      setState(() {
        _loadingBirthdays = false;
        todayBirthdays = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load birthday data: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

String _formatDateForAPI(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  
  final formatted = '$day-$month-$year';
  debugPrint('Formatted date for API: $formatted');
  return formatted;
}

  Future<void> _loadUserData() async {
    try {
      final completeData = await UserInformationService.getCompleteUserData();
      if (completeData != null && completeData.containsKey('data')) {
        _setUserDataFromMap(completeData['data']);
        return;
      }

      final userInfo = await UserInformationService.getSavedUserInformation();
      if (userInfo.isNotEmpty && userInfo['userId']?.isNotEmpty == true) {
        _setUserDataFromInfoMap(userInfo);
        return;
      }

      final profileInfo = await UserInformationService.getUserProfileForDisplay();
      if (profileInfo.isNotEmpty) {
        setState(() {
          fullName = profileInfo['fullName'] ?? 'Dr. Staff Member';
          userId = profileInfo['userId'] ?? '';
          clinicName = profileInfo['clinic'] ?? 'Smart Care Hospital';
          userRole = profileInfo['role'] ?? 'Medical Staff';
          email = profileInfo['email'] ?? '';
          phoneNumber = profileInfo['phone'] ?? '';
          accessGroup = profileInfo['accessGroup'] ?? 'Admin Staff';
          location = profileInfo['location'] ?? 'Main Hospital - Floor 3';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _setUserDataFromMap(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      userId = data['userId']?.toString() ?? '';
      String first = data['firstName']?.toString() ?? '';
      String last = data['lastName']?.toString() ?? '';
      String init = data['initial']?.toString() ?? '';
      
      fullName = '$init $first $last'.trim();
      if (fullName.isEmpty) fullName = userId;
      
      clinicName = data['clinicName']?.toString() ?? 'Smart Care Hospital';
      String job = data['jobtitle']?.toString() ?? '';
      userRole = job.isNotEmpty ? job : 'Medical Staff';
      
      email = data['email']?.toString() ?? '';
      phoneNumber = data['mobileNo']?.toString() ?? '';
      address = data['address']?.toString() ?? '';
      accessGroup = data['accessGroup']?.toString() ?? 'Admin Staff';
      location = data['location']?.toString() ?? 'Main Hospital - Floor 3';
      
      isLoading = false;
    });
  }

  void _setUserDataFromInfoMap(Map<String, dynamic> userInfo) {
    if (!mounted) return;
    setState(() {
      userId = userInfo['userId']?.toString() ?? '';
      String first = userInfo['firstName']?.toString() ?? '';
      String last = userInfo['lastName']?.toString() ?? '';
      String init = userInfo['initial']?.toString() ?? '';

      fullName = '$init $first $last'.trim();
      if (fullName.isEmpty) fullName = userId;

      clinicName = userInfo['clinicName']?.toString() ?? 'Smart Care Hospital';
      String job = userInfo['jobtitle']?.toString() ?? '';
      userRole = job.isNotEmpty ? job : 'Medical Staff';
      
      email = userInfo['email']?.toString() ?? '';
      phoneNumber = userInfo['mobileNo']?.toString() ?? '';
      address = userInfo['address']?.toString() ?? '';
      accessGroup = userInfo['accessGroup']?.toString() ?? 'Admin Staff';
      location = userInfo['location']?.toString() ?? 'Main Hospital - Floor 3';

      isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: Text("Logout", style: GoogleFonts.poppins(color: AppColors.errorRed)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        _isLoggingOut = false;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const WelcomePage(),
          fullscreenDialog: true,
        ),
        (Route<dynamic> route) => false,
      );
    } finally {
      _isLoggingOut = false;
    }
  }

  void _showBirthdayDetails() {
    final today = DateTime.now();
    final todayFormatted = DateFormat('dd-MM-yyyy').format(today);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cake, color: AppColors.pink, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Birthdays",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          todayFormatted,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (todayBirthdays.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${todayBirthdays.length} Staff",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_loadingBirthdays)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: AppColors.pink),
                  ),
                )
              else if (todayBirthdays.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No birthdays today",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No staff have birthdays today",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "API Response: Empty data array",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.warningOrange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ...todayBirthdays.map((staff) => _buildStaffBirthdayCard(staff)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Close",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildStaffBirthdayCard(StaffDOB staff) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.pink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.cake, color: AppColors.pink, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff.fullName.isNotEmpty ? staff.fullName : 'Staff Member',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              if (staff.initial != null && staff.initial!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    "👤 ${staff.initial!}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textBodyColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              if (staff.dob != null && staff.dob!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    "🎂 ${staff.dob!}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textBodyColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "🎂",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.pink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Today",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  void _showEventDetails(String title) {
    List<Widget> content = [];
    
    if (title == "Birthdays") {
      content = upcomingBirthdays.map((bday) => _buildDetailCard(
        icon: Icons.cake,
        title: bday.name,
        subtitle: bday.department,
        trailing: bday.time,
        color: AppColors.pink,
      )).toList();
    } else if (title == "Trainings") {
      content = trainings.map((training) => _buildDetailCard(
        icon: Icons.school,
        title: training.title,
        subtitle: training.date,
        trailing: training.status,
        color: AppColors.infoBlue,
      )).toList();
    } else if (title == "My Rota") {
      content = rotaShifts.map((rota) => _buildDetailCard(
        icon: Icons.schedule,
        title: rota.shift,
        subtitle: rota.location,
        trailing: rota.date,
        color: AppColors.purple,
      )).toList();
    } else if (title == "My Tasks") {
      content = quickTasks.map((task) => _buildDetailCard(
        icon: task.completed ? Icons.check_circle : Icons.assignment,
        title: task.title,
        subtitle: "${task.time} • ${task.priority} Priority",
        trailing: task.completed ? "Completed" : "Pending",
        color: task.completed ? AppColors.successGreen : _getPriorityColor(task.priority),
      )).toList();
    } else if (title == "Approvals") {
      content = pendingApprovals.map((approval) => _buildDetailCard(
        icon: Icons.pending_actions,
        title: "${approval.type} - ${approval.name}",
        subtitle: approval.days.isNotEmpty ? approval.days : (approval.hours.isNotEmpty ? approval.hours : approval.items),
        trailing: approval.status,
        color: AppColors.warningOrange,
      )).toList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "$title Details",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: content,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Close",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textBodyColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCheckInOut() {
    setState(() {
      if (checkInOutStatus.checkedIn) {
        checkInOutStatus = CheckInOutStatus(
          checkedIn: false,
          checkInTime: '--:--',
          location: 'Not Set',
          totalHours: '0.0',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked out successfully', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        final now = DateTime.now();
        final formattedTime = DateFormat('hh:mm a').format(now);
        checkInOutStatus = CheckInOutStatus(
          checkedIn: true,
          checkInTime: formattedTime,
          location: 'Main Hospital',
          totalHours: '0.0',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked in successfully at $formattedTime', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;

    final double horizontalPadding = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      extendBodyBehindAppBar: false,
      drawer: UserProfileDrawer(
        fullName: fullName,
        userRole: userRole,
        clinicName: clinicName,
        userId: userId,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        accessGroup: accessGroup,
        location: location,
        onLogout: _handleLogout,
      ),
      body: SafeArea(
        child: isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDarkBlue))
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        onPressed: () => Scaffold.of(context).openDrawer(),
                                        icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    );
                                  }
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                currentDate,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                      
                        Text(
                          "Welcome,",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        
                        const SizedBox(height: 2),
                        
                        Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        Text(
                          userRole,
                          style: GoogleFonts.poppins(
                            color: AppColors.lightBlue,
                            fontSize: 12,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                 
                        Row(
                          children: [
                            _buildSmallStatItem(
                              icon: Icons.group,
                              value: todayBirthdays.length.toString(),
                              label: "Today's Birthdays",
                              color: AppColors.accentTeal,
                            ),
                            const SizedBox(width: 8),
                            _buildSmallStatItem(
                              icon: Icons.task,
                              value: "4",
                              label: "Tasks",
                              color: AppColors.warningOrange,
                            ),
                            const SizedBox(width: 8),
                            _buildSmallStatItem(
                              icon: Icons.check_circle,
                              value: "8",
                              label: "Done",
                              color: AppColors.successGreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView(
                        padding: EdgeInsets.all(horizontalPadding),
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 375),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            const SizedBox(height: 16),
                            
                            _buildCompactSectionHeader(
                              title: "Today's Events",
                              icon: Icons.event,
                              context: context,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              height: 130,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildCompactEventCard(
                                    title: "Birthdays",
                                    count: todayBirthdays.length,
                                    icon: Icons.cake,
                                    color: AppColors.pink,
                                    context: context,
                                    onTap: _showBirthdayDetails,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildCompactEventCard(
                                    title: "Trainings",
                                    count: trainings.length,
                                    icon: Icons.school,
                                    color: AppColors.infoBlue,
                                    context: context,
                                    onTap: () => _showEventDetails("Trainings"),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildCompactEventCard(
                                    title: "My Rota",
                                    count: rotaShifts.length,
                                    icon: Icons.schedule,
                                    color: AppColors.purple,
                                    context: context,
                                    onTap: () => _showEventDetails("My Rota"),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 400) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildCompactSectionHeader(
                                        title: "My Tasks",
                                        icon: Icons.task_alt,
                                        context: context,
                                      ),
                                      const SizedBox(height: 12),
                                      ...quickTasks.take(2).map((task) => 
                                        _buildCompactTaskItem(task, context)
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSeeAllButton(
                                        onTap: () => _showEventDetails("My Tasks"),
                                        context: context,
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      _buildCompactSectionHeader(
                                        title: "Approvals Pending",
                                        icon: Icons.pending_actions,
                                        context: context,
                                      ),
                                      const SizedBox(height: 12),
                                      ...pendingApprovals.take(2).map((approval) => 
                                        _buildCompactApprovalItem(approval, context)
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSeeAllButton(
                                        onTap: () => _showEventDetails("Approvals"),
                                        context: context,
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildCompactSectionHeader(
                                              title: "My Tasks",
                                              icon: Icons.task_alt,
                                              context: context,
                                            ),
                                            const SizedBox(height: 12),
                                            ...quickTasks.take(2).map((task) => 
                                              _buildCompactTaskItem(task, context)
                                            ),
                                            const SizedBox(height: 12),
                                            _buildSeeAllButton(
                                              onTap: () => _showEventDetails("My Tasks"),
                                              context: context,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildCompactSectionHeader(
                                              title: "Approvals Pending",
                                              icon: Icons.pending_actions,
                                              context: context,
                                            ),
                                            const SizedBox(height: 12),
                                            ...pendingApprovals.take(2).map((approval) => 
                                              _buildCompactApprovalItem(approval, context)
                                            ),
                                            const SizedBox(height: 12),
                                            _buildSeeAllButton(
                                              onTap: () => _showEventDetails("Approvals"),
                                              context: context,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            _buildCompactCheckInOutWidget(context),
                            
                            const SizedBox(height: 20),
                            _buildCustomExpansionSection(
                              title: "Today's Birthdays",
                              icon: Icons.cake,
                              children: _loadingBirthdays
                                  ? [
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(color: AppColors.pink),
                                        ),
                                      )
                                    ]
                                  : todayBirthdays.isEmpty
                                      ? [
                                          _buildEmptyBirthdayState()
                                        ]
                                      : todayBirthdays.take(2).map((staff) => 
                                          _buildCompactStaffListItem(staff, context)
                                        ).toList(),
                              context: context,
                              onSeeAll: _showBirthdayDetails,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            _buildCustomExpansionSection(
                              title: "Trainings",
                              icon: Icons.school,
                              children: trainings.take(2).map((training) => 
                                _buildCompactListItem(
                                  icon: Icons.school,
                                  title: training.title,
                                  subtitle: training.date,
                                  trailing: training.status,
                                  color: AppColors.infoBlue,
                                  context: context,
                                )
                              ).toList(),
                              context: context,
                              onSeeAll: () => _showEventDetails("Trainings"),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            _buildCustomExpansionSection(
                              title: "My Rota",
                              icon: Icons.schedule,
                              children: rotaShifts.take(2).map((rota) => 
                                _buildCompactListItem(
                                  icon: Icons.schedule,
                                  title: rota.shift,
                                  subtitle: rota.location,
                                  trailing: rota.date,
                                  color: AppColors.purple,
                                  context: context,
                                )
                              ).toList(),
                              context: context,
                              onSeeAll: () => _showEventDetails("My Rota"),
                            ),
                            
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyBirthdayState() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.lightGreyColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.pink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cake_outlined, color: AppColors.pink, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No birthdays today",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  "Enjoy the day!",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "API returned empty data",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.warningOrange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCompactStaffListItem(StaffDOB staff, BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.lightGreyColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.pink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cake, color: AppColors.pink, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff.fullName.isNotEmpty ? staff.fullName : 'Staff Member',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (staff.initial != null && staff.initial!.isNotEmpty)
                Text(
                  staff.initial!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "Today",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.pink,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSmallStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSectionHeader({
    required String title,
    required IconData icon,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryDarkBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryDarkBlue, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactEventCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: screenWidth * 0.35,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  "$count",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  "View Details",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 12, color: AppColors.textBodyColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTaskItem(QuickTask task, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              task.completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.completed ? AppColors.successGreen : _getPriorityColor(task.priority),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${task.time} • ${task.priority} Priority",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactApprovalItem(PendingApproval approval, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.pending,
              color: AppColors.warningOrange,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approval.type,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approval.name,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Pending",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.warningOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeAllButton({
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryDarkBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "See All",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryDarkBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCheckInOutWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                  color: AppColors.accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.login, color: AppColors.accentTeal, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                "Check-in / Check-out",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          if (isSmallScreen)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Status",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusChip(),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Check-in Time",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          checkInOutStatus.checkInTime,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hours Today",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${checkInOutStatus.totalHours}h",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Check-in Time",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      checkInOutStatus.checkInTime,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hours Today",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${checkInOutStatus.totalHours}h",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleCheckInOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: checkInOutStatus.checkedIn 
                    ? AppColors.errorRed 
                    : AppColors.successGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                checkInOutStatus.checkedIn ? "Check Out Now" : "Check In Now",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: checkInOutStatus.checkedIn 
            ? AppColors.successGreen.withOpacity(0.1)
            : AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checkInOutStatus.checkedIn ? Icons.check_circle : Icons.circle,
            size: 10,
            color: checkInOutStatus.checkedIn 
                ? AppColors.successGreen 
                : AppColors.errorRed,
          ),
          const SizedBox(width: 4),
          Text(
            checkInOutStatus.checkedIn ? "Checked In" : "Checked Out",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: checkInOutStatus.checkedIn 
                  ? AppColors.successGreen 
                  : AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomExpansionSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required BuildContext context,
    required VoidCallback onSeeAll,
  }) {
    return Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDarkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: AppColors.primaryDarkBlue, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onSeeAll,
                  child: Row(
                    children: [
                      Text(
                        "See All",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primaryDarkBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryDarkBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightGreyColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textBodyColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.errorRed;
      case 'medium':
        return AppColors.warningOrange;
      case 'low':
        return AppColors.successGreen;
      default:
        return AppColors.textBodyColor;
    }
  }
}

class Birthday {
  final String name;
  final String department;
  final String time;

  Birthday({required this.name, required this.department, required this.time});
}

class Training {
  final String title;
  final String date;
  final String status;

  Training({required this.title, required this.date, required this.status});
}

class RotaShift {
  final String date;
  final String shift;
  final String location;

  RotaShift({required this.date, required this.shift, required this.location});
}

class QuickTask {
  final String title;
  final String priority;
  final String time;
  final bool completed;

  QuickTask({
    required this.title,
    required this.priority,
    required this.time,
    required this.completed,
  });
}

class PendingApproval {
  final String type;
  final String name;
  final String days;
  final String hours;
  final String items;
  final String status;

  PendingApproval({
    required this.type,
    required this.name,
    this.days = '',
    this.hours = '',
    this.items = '',
    required this.status,
  });
}

class CheckInOutStatus {
  bool checkedIn;
  String checkInTime;
  String location;
  String totalHours;

  CheckInOutStatus({
    this.checkedIn = false,
    this.checkInTime = '--:--',
    this.location = 'Not Set',
    this.totalHours = '0.0',
  });
}

class UserProfileDrawer extends StatefulWidget {
  final String fullName;
  final String userRole;
  final String clinicName;
  final String userId;
  final String email;
  final String phoneNumber;
  final String address;
  final String accessGroup;
  final String location;
  final VoidCallback onLogout;

  const UserProfileDrawer({
    super.key,
    required this.fullName,
    required this.userRole,
    required this.clinicName,
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.accessGroup,
    required this.location,
    required this.onLogout,
  });

  @override
  State<UserProfileDrawer> createState() => _UserProfileDrawerState();
}

class _UserProfileDrawerState extends State<UserProfileDrawer> {

  bool _hrExpanded = false;
  bool _ticketExpanded = false;
  
  bool _isLogoutHovering = false;
  final Map<String, bool> _hoverStates = {};

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final String initial = widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : 'S';

    return Drawer(
      width: size.width * 0.85,
      backgroundColor: AppColors.drawerBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          initial,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDarkBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fullName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.userRole,
                              style: GoogleFonts.poppins(
                                color: AppColors.lightBlue,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.clinicName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.iconBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_outline, color: AppColors.iconBlue, size: 22),
                        ),
                        title: Text(
                          "My Profile",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textBodyColor),
                        onTap: () => _navigateToProfile(context),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.iconOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_reset_outlined, color: AppColors.iconOrange, size: 22),
                        ),
                        title: Text(
                          "Forgot Password",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textBodyColor),
                        onTap: () => _navigateToForgotPassword(context),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // My HR Section
                    _buildMenuSection(
                      title: "My HR",
                      isExpanded: _hrExpanded,
                      onTap: () => setState(() => _hrExpanded = !_hrExpanded),
                      icon: Icons.work_outline,
                      iconColor: AppColors.iconGreen,
                      children: [
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: "Leave Management",
                          children: [
                            _buildMenuItem(
                              label: "Leave Balance",
                              onTap: () => _navigateToMyHR(context, section: 1),
                              icon: Icons.beach_access_outlined,
                            ),
                            _buildMenuItem(
                              label: "Apply Leave",
                              onTap: () => _navigateToMyHR(context, section: 1, openDialog: 'apply_leave'),
                              icon: Icons.add_circle_outline,
                            ),
                            _buildMenuItem(
                              label: "Leave History",
                              onTap: () => _navigateToMyHR(context, section: 1),
                              icon: Icons.history_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: " OT / OD",
                          children: [
                            _buildMenuItem(
                              label: "Apply OT",
                              onTap: () => _navigateToMyHR(context, section: 2, openDialog: 'apply_ot'),
                              icon: Icons.timer_outlined,
                            ),
                            _buildMenuItem(
                              label: "Apply OD",
                              onTap: () => _navigateToMyHR(context, section: 2, openDialog: 'apply_od'),
                              icon: Icons.assignment_outlined,
                            ),
                            _buildMenuItem(
                              label: "View History",
                              onTap: () => _navigateToMyHR(context, section: 2),
                              icon: Icons.list_alt_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: "Attendance",
                          children: [
                            _buildMenuItem(
                              label: "Check-in",
                              onTap: () => _navigateToMyHR(context, section: 3, openDialog: 'check_in'),
                              icon: Icons.login_outlined,
                            ),
                            _buildMenuItem(
                              label: "Check-out",
                              onTap: () => _navigateToMyHR(context, section: 3, openDialog: 'check_out'),
                              icon: Icons.logout_outlined,
                            ),
                            _buildMenuItem(
                              label: "Attendance History",
                              onTap: () => _navigateToMyHR(context, section: 3),
                              icon: Icons.calendar_view_month_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: "Salary",
                          children: [
                            _buildMenuItem(
                              label: "Salary Summary",
                              onTap: () => _navigateToMyHR(context, section: 4),
                              icon: Icons.attach_money_outlined,
                            ),
                            _buildMenuItem(
                              label: "Payslip Download",
                              onTap: () => _navigateToMyHR(context, section: 4, openDialog: 'download_payslip'),
                              icon: Icons.download_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildMenuSection(
                      title: "Submit Ticket",
                      isExpanded: _ticketExpanded,
                      onTap: () => setState(() => _ticketExpanded = !_ticketExpanded),
                      icon: Icons.support_agent_outlined,
                      iconColor: AppColors.iconOrange,
                      children: [
                        _buildSubSection(
                          title: "Create Ticket",
                          children: [
                            _buildMenuItem(
                              label: "Category",
                              onTap: () => _navigateToSubmitTicket(context),
                              icon: Icons.category_outlined,
                            ),
                            _buildMenuItem(
                              label: "Description",
                              onTap: () => _navigateToSubmitTicket(context),
                              icon: Icons.description_outlined,
                            ),
                            _buildMenuItem(
                              label: "Attachment",
                              onTap: () => _navigateToSubmitTicket(context),
                              icon: Icons.attach_file_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: "Ticket List",
                          children: [
                            _buildMenuItem(
                              label: "Open Tickets",
                              onTap: () => _navigateToSubmitTicket(context, tab: 1),
                              icon: Icons.folder_open_outlined,
                            ),
                            _buildMenuItem(
                              label: "Closed Tickets",
                              onTap: () => _navigateToSubmitTicket(context, tab: 2),
                              icon: Icons.folder_copy_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSubSection(
                          title: "Ticket Details",
                          children: [
                            _buildMenuItem(
                              label: "Status",
                              onTap: () => _navigateToSubmitTicket(context, tab: 1),
                              icon: Icons.info_outlined,
                            ),
                            _buildMenuItem(
                              label: "Comments",
                              onTap: () => _navigateToSubmitTicket(context, tab: 1),
                              icon: Icons.chat_bubble_outline,
                            ),
                            _buildMenuItem(
                              label: "Resolution",
                              onTap: () => _navigateToSubmitTicket(context, tab: 2),
                              icon: Icons.check_circle_outline,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            label: "Settings",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsPage()),
                              );
                            },
                            icon: Icons.settings_outlined,
                            showBorder: false,
                          ),
                          Divider(height: 1, color: AppColors.dividerColor, indent: 16),
                          _buildMenuItem(
                            label: "Help & Support",
                            onTap: () => _showHelpSupport(context),
                            icon: Icons.help_outline_outlined,
                            showBorder: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.dividerColor, width: 1),
                ),
              ),
              child: Column(
                children: [
                  MouseRegion(
                    onEnter: (_) => setState(() => _isLogoutHovering = true),
                    onExit: (_) => setState(() => _isLogoutHovering = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: _isLogoutHovering
                          ? (Matrix4.identity()..scale(1.02))
                          : Matrix4.identity(),
                      child: ElevatedButton.icon(
                        onPressed: widget.onLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isLogoutHovering
                              ? AppColors.errorRed.withOpacity(0.9)
                              : AppColors.errorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isLogoutHovering ? 3 : 1,
                          shadowColor: AppColors.errorRed.withOpacity(0.3),
                        ),
                        icon: const Icon(Icons.logout_outlined, size: 18),
                        label: Text(
                          "Logout",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _showPrivacyPolicy(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          "Privacy Policy",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textBodyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showTerms(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          "Terms of Service",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textBodyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Version 11.0.1 • SmartCare © 2024",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textBodyColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
          ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textBodyColor,
            ),
            onTap: onTap,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark.withOpacity(0.7),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.lightGreyColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
    bool isImportant = false,
    bool showBorder = true,
  }) {
    final String key = label;
    _hoverStates.putIfAbsent(key, () => false);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverStates[key] = true),
      onExit: (_) => setState(() => _hoverStates[key] = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hoverStates[key]! ? AppColors.menuItemHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: showBorder && !_hoverStates[key]!
                ? Border(
                    bottom: BorderSide(color: AppColors.dividerColor, width: 0.5),
                  )
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              icon,
              color: isImportant ? AppColors.iconOrange : AppColors.textBodyColor,
              size: 20,
            ),
            title: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isImportant ? AppColors.iconOrange : AppColors.textDark,
                fontWeight: isImportant ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _navigateToForgotPassword(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  void _navigateToMyHR(BuildContext context, {
    required int section,
    String? openDialog,
  }) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHRScreen(
          initialSection: section,
          openDialog: openDialog,
        ),
      ),
    );
  }

  void _navigateToSubmitTicket(BuildContext context, {int tab = 0}) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubmitTicketPage()),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Help & Support", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Contact Support:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDetailRow("Email", "support@smartcare.com"),
            _buildDetailRow("Phone", "+1 (555) 123-4567"),
            _buildDetailRow("Hours", "Mon-Fri, 9AM-6PM"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Privacy Policy", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const SingleChildScrollView(
          child: Text(
            "Your privacy is important to us. This privacy policy explains what personal data we collect from you and how we use it.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Terms of Service", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const SingleChildScrollView(
          child: Text(
            "By using our services, you agree to our terms of service. Please read them carefully.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$title:",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}