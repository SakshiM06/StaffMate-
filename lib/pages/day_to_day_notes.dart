import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A2C42);
  static const Color midDarkBlue = Color(0xFF273F5A);
  static const Color appBarColor = Color(0xFF1A237E);
  static const Color textBackground = Color(0xFF1A237E);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color darkerAccentTeal = Color(0xFF00A37D);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  static const Color fieldFillColor = Color(0xFFE3E8ED);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color accentBlue = Color(0xFF1E88E5);
  static const Color tableHeaderColor = Color(0xFFF5F5F5);
  static const Color tableBorderColor = Color(0xFFE0E0E0);
  static const Color cardShadow = Color(0x1A000000);
  static const Color successGreen = Color(0xFF4CAF50);
}

class DayToDayNotesPage extends StatefulWidget {
  final int initialDay;
  final String admissionId;
  final String admissionDate;
  final String patientName;
  final String patientId;
  
  const DayToDayNotesPage({
    super.key,
    this.initialDay = 32,
    required this.admissionId,
    required this.admissionDate,
    required this.patientName,
    required this.patientId, required String ipdId,
  });

  @override
  State<DayToDayNotesPage> createState() => _DayToDayNotesPageState();
}

class _DayToDayNotesPageState extends State<DayToDayNotesPage> with SingleTickerProviderStateMixin {
  final TextEditingController dayController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  
  int selectedDay = 32;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> notesList = [];
  
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final IpdService _ipdService = IpdService();
  
  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDay;
    dayController.text = selectedDay.toString();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDayToDayNotes();
    });
  }
  
  @override
  void dispose() {
    dayController.dispose();
    notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    try {
      String dateStr = date.toString();
      if (dateStr.contains(' ')) return dateStr.split(' ')[0];
      return dateStr;
    } catch (e) {
      return 'N/A';
    }
  }
  
  Future<String> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userId') ?? prefs.getString('userFullName') ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }
  
  Future<void> _loadDayToDayNotes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final result = await _ipdService.fetchDayToDayNotes(
        ipdid: widget.admissionId,
        admissiondate: widget.admissionDate,
      );
      
      if (mounted) {
        setState(() {
          isLoading = false;
          
          if (result['success'] == true) {
            final data = result['data'];
            if (data is List) {
              notesList = data.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final note = entry.value;
                return {
                  'srNo': index,
                  'id': note['id'] ?? note['srNo'] ?? 0,
                  'day': note['day'] ?? note['dayNumber'] ?? 'N/A',
                  'notes': note['notes'] ?? note['dayToDayNotes'] ?? note['description'] ?? 'No notes',
                  'date': note['date'] ?? note['createdDate'] ?? '',
                  'createdBy': note['createdBy'] ?? note['createdByUserName'] ?? '',
                };
              }).toList();
              
              notesList.sort((a, b) {
                final dayA = int.tryParse(a['day'].toString()) ?? 0;
                final dayB = int.tryParse(b['day'].toString()) ?? 0;
                return dayB.compareTo(dayA);
              });
              
              // Reassign SR numbers after sorting
              for (int i = 0; i < notesList.length; i++) {
                notesList[i]['srNo'] = i + 1;
              }
            } else {
              notesList = [];
            }
          } else {
            errorMessage = result['message'] ?? 'Failed to load notes';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _saveNoteToApi() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isSaving = true);
    
    try {
      final userId = await _getCurrentUserId();
      
      final result = await _ipdService.saveDayToDayNote(
        ipdid: widget.admissionId,
        admissiondate: widget.admissionDate,
        notes: notesController.text.trim(),
        day: selectedDay,
        id: 0,
        createdByUserId: userId,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          await _loadDayToDayNotes();
          notesController.clear();
          FocusScope.of(context).unfocus();
          _showSnackBar('Note added for Day $selectedDay', AppColors.successGreen);
        } else {
          _showSnackBar('Failed: ${result['message']}', AppColors.errorRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _clearForm() {
    notesController.clear();
    _formKey.currentState?.reset();
    dayController.text = selectedDay.toString();
    FocusScope.of(context).unfocus();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    
    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildCompactHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDayToDayNotes,
                color: AppColors.appBarColor,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.all(horizontalPadding),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildCompactPatientInfo(),
                          const SizedBox(height: 12),
                          _buildCompactInputForm(),
                          const SizedBox(height: 16),
                          _buildNotesCounter(),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),
                    
                    isLoading && notesList.isEmpty
                        ? SliverFillRemaining(child: _buildCompactLoading())
                        : errorMessage != null && notesList.isEmpty
                            ? SliverFillRemaining(child: _buildCompactError())
                            : notesList.isEmpty
                                ? SliverFillRemaining(child: _buildCompactEmpty())
                                : SliverPadding(
                                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: _buildCompactNoteCard(notesList[index], index),
                                        ),
                                        childCount: notesList.length,
                                      ),
                                    ),
                                  ),
                    
                    SliverPadding(padding: EdgeInsets.only(bottom: horizontalPadding)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompactHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 4,
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.appBarColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(LineIcons.arrowLeft, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Day to Day Notes",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.patientName,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: screenWidth * 0.035,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _loadDayToDayNotes,
              icon: const Icon(LineIcons.syncIcon, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactPatientInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.appBarColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LineIcons.hospital, color: AppColors.appBarColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'IPD: ${widget.admissionId} | ${widget.admissionDate}',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textBodyColor, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactInputForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreyColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: TextFormField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      enabled: !isSaving,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Day',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textBodyColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      onChanged: (value) {
                        if (value.isNotEmpty && int.tryParse(value) != null) {
                          setState(() => selectedDay = int.parse(value));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreyColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: TextFormField(
                      controller: notesController,
                      enabled: !isSaving,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter notes...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textBodyColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : _clearForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (isLoading || isSaving) ? null : _saveNoteToApi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.appBarColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Add Note',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
  
  Widget _buildNotesCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            "All Notes",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primaryDarkBlue),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.appBarColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${notesList.length}',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.appBarColor),
            ),
          ),
          const Spacer(),
          Text(
            '${notesList.length} entries',
            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textBodyColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactNoteCard(Map<String, dynamic> note, int index) {
    final dayNumber = note['day'].toString();
    final noteText = note['notes'].toString();
    final noteDate = _formatDate(note['date']);
    final srNo = note['srNo'] ?? index + 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.appBarColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$srNo',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.appBarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.appBarColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Day $dayNumber',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.appBarColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(LineIcons.calendar, size: 8, color: AppColors.textBodyColor),
                    const SizedBox(width: 2),
                    Text(
                      noteDate,
                      style: GoogleFonts.poppins(fontSize: 8, color: AppColors.textBodyColor, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  noteText,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDark, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note['createdBy'] != null && note['createdBy'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'by ${note['createdBy']}',
                      style: GoogleFonts.poppins(fontSize: 8, color: AppColors.textBodyColor, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            width: 30,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.appBarColor),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Loading notes...",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(LineIcons.exclamationTriangle, size: 30, color: Colors.orange.shade400),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryDarkBlue),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              errorMessage ?? 'Something went wrong',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDayToDayNotes,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appBarColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Try Again', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(LineIcons.stickyNote, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          Text(
            "No Notes Yet",
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDarkBlue),
          ),
          const SizedBox(height: 4),
          Text(
            "Add your first note above",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}