import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:line_icons/line_icons.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/submit_ticket_page.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/services/user_information_service.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textBodyColor = Color(0xFF4A5568);
  static const Color lightGreyColor = Color(0xFFF5F7FA);
  static const Color fieldFillColor = Color(0xFFF5F5F5);
  static const Color errorRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF4CAF50);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User Information
  String fullName = 'Staff Member';
  String userId = '';
  String phoneNumber = '';
  String email = '';
  String userRole = 'Employee';
  String clinicName = '';
  String initial = '';
  String firstName = '';
  String lastName = '';
  String jobTitle = '';
  String userType = '';
  String address = '';
  String city = '';
  String state = '';
  String country = '';
  String pinCode = '';
  String branchAbbreviation = '';
  
  // Additional fields
  String landLine = '';
  String lastPasswordDate = '';
  String globalAccess = '';
  String hasDiary = '';
  String sectionName = '';
  String specializationId = '';
  String empId = '';

  bool isEditing = false;
  bool isLoading = false;
  bool apiError = false;
  bool hasData = false;
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _pinCodeController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _pinCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
      apiError = false;
      hasData = false;
    });
    
    try {
      final completeData = await UserInformationService.getCompleteUserData();
      
      if (completeData != null && completeData.containsKey('data')) {
        final data = completeData['data'];
        _setUserDataFromMap(data);
        hasData = true;
        return;
      }
      
      final userInfo = await UserInformationService.getSavedUserInformation();
      if (userInfo.isNotEmpty && userInfo['userId']?.isNotEmpty == true) {
        _setUserDataFromInfoMap(userInfo);
        hasData = true;
        return;
      }
      
      final profileInfo = await UserInformationService.getUserProfileForDisplay();
      if (profileInfo.isNotEmpty && profileInfo['fullName']?.isNotEmpty == true) {
        _setUserDataFromProfileMap(profileInfo);
        hasData = true;
        return;
      }
      
      setState(() {
        apiError = true;
        hasData = false;
      });
      
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      setState(() {
        apiError = true;
        hasData = false;
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _setUserDataFromMap(Map<String, dynamic> data) {
    setState(() {
      userId = data['userId']?.toString() ?? '';
      firstName = data['firstName']?.toString() ?? '';
      lastName = data['lastName']?.toString() ?? '';
      initial = data['initial']?.toString() ?? '';
      phoneNumber = data['mobileNo']?.toString() ?? '';
      email = data['email']?.toString() ?? '';
      jobTitle = data['jobtitle']?.toString() ?? '';
      clinicName = data['clinicName']?.toString() ?? '';
      userType = data['userType']?.toString() ?? '';
      
      fullName = '$initial $firstName $lastName'.trim();
      if (fullName.isEmpty || fullName == ' ') {
        fullName = userId.isNotEmpty ? userId : 'User';
      }
      
      address = data['address']?.toString() ?? '';
      city = data['city']?.toString() ?? '';
      state = data['state']?.toString() ?? '';
      country = data['country']?.toString() ?? '';
      pinCode = data['pinCode']?.toString() ?? '';
      
      userRole = jobTitle.isNotEmpty ? jobTitle : 'Staff';
      
      _phoneController.text = phoneNumber;
      _emailController.text = email;
      _addressController.text = address;
      _cityController.text = city;
      _stateController.text = state;
      _countryController.text = country;
      _pinCodeController.text = pinCode;
    });
  }

  void _setUserDataFromInfoMap(Map<String, dynamic> userInfo) {
    setState(() {
      userId = userInfo['userId']?.toString() ?? '';
      firstName = userInfo['firstName']?.toString() ?? '';
      lastName = userInfo['lastName']?.toString() ?? '';
      initial = userInfo['initial']?.toString() ?? '';
      phoneNumber = userInfo['mobileNo']?.toString() ?? '';
      email = userInfo['email']?.toString() ?? '';
      jobTitle = userInfo['jobtitle']?.toString() ?? '';
      clinicName = userInfo['clinicName']?.toString() ?? '';
      
      fullName = '$initial $firstName $lastName'.trim();
      if (fullName.isEmpty || fullName == ' ') {
        fullName = userId.isNotEmpty ? userId : 'User';
      }
      
      address = userInfo['address']?.toString() ?? '';
      city = userInfo['city']?.toString() ?? '';
      state = userInfo['state']?.toString() ?? '';
      country = userInfo['country']?.toString() ?? '';
      pinCode = userInfo['pinCode']?.toString() ?? '';
      
      userRole = jobTitle.isNotEmpty ? jobTitle : 'Staff';
      
      _phoneController.text = phoneNumber;
      _emailController.text = email;
      _addressController.text = address;
      _cityController.text = city;
      _stateController.text = state;
      _countryController.text = country;
      _pinCodeController.text = pinCode;
    });
  }

  void _setUserDataFromProfileMap(Map<String, String> profileInfo) {
    setState(() {
      fullName = profileInfo['fullName'] ?? 'User';
      userId = profileInfo['userId'] ?? '';
      phoneNumber = profileInfo['phone'] ?? '';
      email = profileInfo['email'] ?? '';
      userRole = profileInfo['role'] ?? 'Staff';
      clinicName = profileInfo['clinic'] ?? '';
      branchAbbreviation = profileInfo['branch'] ?? '';
      
      _phoneController.text = phoneNumber;
      _emailController.text = email;
    });
  }

  Future<void> logout() async {
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

    if (confirm != true) return;

    await SessionManager.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomePage()),
      (Route<dynamic> route) => false,
    );
  }

  void _toggleEditMode() {
    setState(() {
      if (isEditing) {
        _phoneController.text = phoneNumber;
        _emailController.text = email;
        _addressController.text = address;
        _cityController.text = city;
        _stateController.text = state;
        _countryController.text = country;
        _pinCodeController.text = pinCode;
      }
      isEditing = !isEditing;
    });
  }

  void _saveChanges() async {
    if (_phoneController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Phone and Email are required fields"), 
          backgroundColor: AppColors.errorRed
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('mobileNo', _phoneController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('address', _addressController.text);
    await prefs.setString('city', _cityController.text);
    await prefs.setString('state', _stateController.text);
    await prefs.setString('country', _countryController.text);
    await prefs.setString('pinCode', _pinCodeController.text);
    
    setState(() {
      phoneNumber = _phoneController.text;
      email = _emailController.text;
      address = _addressController.text;
      city = _cityController.text;
      state = _stateController.text;
      country = _countryController.text;
      pinCode = _pinCodeController.text;
      isEditing = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LineIcons.checkCircle, color: Colors.white),
            const SizedBox(width: 10),
            Text('Profile changes saved!', style: GoogleFonts.nunito(color: Colors.white)),
          ],
        ),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGreyColor,
      drawer: _buildModernDrawer(),
      body: isLoading 
          ? _buildLoadingScreen()
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Column(
                      children: [
                        // Personal Details Card (Fixed Box, No Scroll)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05), 
                                  blurRadius: 10, 
                                  offset: const Offset(0, 5)
                                )
                              ],
                            ),
                            // Column used instead of ListView to prevent scrolling
                            child: Column(
                              children: [
                                // Title Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Personal Information", 
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 15, 
                                        color: AppColors.primaryDarkBlue
                                      )
                                    ),
                                    if(isEditing)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.successGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          "Editing", 
                                          style: GoogleFonts.poppins(
                                            fontSize: 9, 
                                            color: AppColors.successGreen, 
                                            fontWeight: FontWeight.w600
                                          )
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                
                                // Fields distributed evenly in remaining space
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildProfileField(
                                        label: "User ID",
                                        value: userId,
                                        icon: LineIcons.userCircle,
                                        isReadOnly: true,
                                      ),
                                      
                                      _buildProfileField(
                                        label: "Full Name",
                                        value: fullName,
                                        icon: LineIcons.user,
                                        isReadOnly: true,
                                      ),
                                      
                                      _buildProfileField(
                                        label: "Phone Number",
                                        controller: _phoneController,
                                        icon: LineIcons.phone,
                                        isEditable: isEditing,
                                      ),
                                      
                                      _buildProfileField(
                                        label: "Email Address",
                                        controller: _emailController,
                                        icon: LineIcons.envelope,
                                        isEditable: isEditing,
                                      ),
                                      
                                      // Compact Address Section
                                      if (isEditing || address.isNotEmpty)
                                        Column(
                                          children: [
                                            _buildProfileField(
                                              label: "Address",
                                              controller: _addressController,
                                              icon: LineIcons.home,
                                              isEditable: isEditing,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildProfileField(
                                                    label: "City",
                                                    controller: _cityController,
                                                    icon: LineIcons.city,
                                                    isEditable: isEditing,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: _buildProfileField(
                                                    label: "State",
                                                    controller: _stateController,
                                                    icon: LineIcons.mapMarker,
                                                    isEditable: isEditing,
                                                  ),
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
                        
                        const SizedBox(height: 10),
                        
                        // Action Buttons - ALWAYS VISIBLE below the card
                        if (hasData) 
                          SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit/Save Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isEditing ? _saveChanges : _toggleEditMode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isEditing 
                                          ? AppColors.successGreen 
                                          : AppColors.primaryDarkBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isEditing ? LineIcons.save : LineIcons.edit, 
                                          size: 16
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEditing ? "Save Changes" : "Edit Profile", 
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13
                                          )
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Logout Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: logout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorRed.withOpacity(0.1),
                                      foregroundColor: AppColors.errorRed,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: AppColors.errorRed.withOpacity(0.3)),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(LineIcons.alternateSignOut, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Log Out", 
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13
                                          )
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
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: AppColors.lightGreyColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryDarkBlue),
            const SizedBox(height: 20),
            Text(
              'Loading profile information...',
              style: GoogleFonts.poppins(color: AppColors.textBodyColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 5, 
        left: 20, 
        right: 20, 
        bottom: 15
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryDarkBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20)
        ),
      ),
      child: Column(
        children: [
          // Row 1: Menu - Title - Avatar (Right Corner)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Menu Icon
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), 
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: const Icon(LineIcons.bars, color: Colors.white, size: 20),
                ),
              ),
              
              // Center: Page Title
              Text(
                "My Profile", 
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w600
                ),
              ),

              // Right: Avatar
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                ),
                child: const CircleAvatar(
                  radius: 20, 
                  backgroundColor: Colors.white,
                  child: Icon(LineIcons.user, size: 22, color: AppColors.primaryDarkBlue),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Row 2: User Information (Centered)
          Column(
            children: [
              Text(
                fullName,
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontSize: 17,
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                userRole,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (clinicName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    clinicName,
                    style: GoogleFonts.nunito(color: AppColors.lightBlue, fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required IconData icon,
    String? value,
    TextEditingController? controller,
    bool isEditable = false,
    bool isReadOnly = false,
  }) {
    final displayValue = value ?? (controller?.text ?? '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Important for spaceEvenly
      children: [
        Text(
          label, 
          style: GoogleFonts.poppins(
            fontSize: 10, 
            fontWeight: FontWeight.w600, 
            color: Colors.grey[600]
          )
        ),
        const SizedBox(height: 2), // Reduced gap
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.lightGreyColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500], size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: isEditable
                    ? TextField(
                        controller: controller,
                        style: GoogleFonts.poppins(
                          fontSize: 12, 
                          fontWeight: FontWeight.w500, 
                          color: AppColors.textDark
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          displayValue.isNotEmpty ? displayValue : 'Not provided',
                          style: GoogleFonts.poppins(
                            fontSize: 12, 
                            fontWeight: FontWeight.w500, 
                            color: isReadOnly ? Colors.grey[600] : AppColors.textDark
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernDrawer() {
    final size = MediaQuery.of(context).size;
    
    return Drawer(
      width: size.width * 0.75,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30), 
          bottomRight: Radius.circular(30)
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 30, left: 20, right: 20),
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
                          fullName,
                          style: GoogleFonts.poppins(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 16
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          userRole,
                          style: GoogleFonts.nunito(color: AppColors.lightBlue, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (clinicName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              clinicName,
                              style: GoogleFonts.nunito(color: Colors.white70, fontSize: 10),
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
                      MaterialPageRoute(builder: (context) => const SubmitTicketPage())
                    );
                  }),
                  _drawerItem(LineIcons.history, "History", () {
                    Navigator.pop(context);
                  }),
                  ExpansionTile(
                    key: const PageStorageKey('attendance_expansion'), 
                    leading: const Icon(LineIcons.calendar, color: AppColors.midDarkBlue, size: 22),
                    title: Text(
                      "Attendance", 
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark, 
                        fontSize: 15, 
                        fontWeight: FontWeight.w500
                      )
                    ),
                    shape: const Border(), 
                    collapsedShape: const Border(),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20), 
                        child: _drawerItem(LineIcons.calendarCheck, "Monthly Report", () {})
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20), 
                        child: _drawerItem(LineIcons.coffee, "Leave Requests", () {})
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
                style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12)
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
          fontWeight: FontWeight.w500
        )
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
      hoverColor: AppColors.lightBlue.withOpacity(0.1),
    );
  }
}