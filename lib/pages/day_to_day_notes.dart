import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';

class AppColors {
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
}

class DayToDayNotesPage extends StatefulWidget {
  final int initialDay;
  
  const DayToDayNotesPage({
    super.key,
    this.initialDay = 32,
  });

  @override
  State<DayToDayNotesPage> createState() => _DayToDayNotesPageState();
}

class _DayToDayNotesPageState extends State<DayToDayNotesPage> {
  // Controllers
  TextEditingController dayController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  
  // Current selected day
  int selectedDay = 32;
  
  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Notes list (empty initially)
  List<Map<String, dynamic>> notesList = [];
  
  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDay;
    dayController.text = selectedDay.toString();
  }
  
  @override
  void dispose() {
    dayController.dispose();
    notesController.dispose();
    super.dispose();
  }
  
  void _addNote() {
    if (_formKey.currentState!.validate()) {
      // API integration will be added here
      // For now, just clear the form
      notesController.clear();
      FocusScope.of(context).unfocus();
    }
  }
  
  void _clearForm() {
    notesController.clear();
    _formKey.currentState?.reset();
    dayController.text = selectedDay.toString();
    FocusScope.of(context).unfocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Input Form Card
                  _buildInputForm(),
                  
                  const SizedBox(height: 20),
                  
                  // Notes Table
                  _buildNotesTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 2,
        left: 20,
        right: 20,
        bottom: 12,
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
          // Back button and title row
          SizedBox(
            height: 36,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LineIcons.arrowLeft, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Day to Day Notes",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "Record daily notes and observations",
              style: GoogleFonts.nunito(
                color: AppColors.lightBlue,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              "ENTER NOTES FOR ( DAY : $selectedDay )",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Day Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Day Number',
                      hintText: 'Enter day number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppColors.lightGreyColor,
                      prefixIcon: Icon(
                        LineIcons.calendar,
                        color: AppColors.accentBlue,
                        size: 18,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter day number';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty && int.tryParse(value) != null) {
                        setState(() {
                          selectedDay = int.parse(value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Info icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LineIcons.infoCircle,
                    color: AppColors.accentBlue,
                    size: 20,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Notes Input
            TextFormField(
              controller: notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Enter Day To Day Notes',
                hintText: 'Type your notes here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppColors.lightGreyColor,
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter notes';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add Notes',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
  
  Widget _buildNotesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tableHeaderColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.tableBorderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    "Sr No.",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Days",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    "Notes",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Table Body
          notesList.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notesList.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppColors.tableBorderColor,
                  ),
                  itemBuilder: (context, index) {
                    final note = notesList[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sr No.
                          Expanded(
                            flex: 1,
                            child: Text(
                              note['id'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textBodyColor,
                              ),
                            ),
                          ),
                          
                          // Days
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                "Day : ${note['day']}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentBlue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          
                          // Notes
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                note['notes'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          
          // Table Footer (if needed)
          if (notesList.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tableHeaderColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.tableBorderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Notes: ${notesList.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textBodyColor,
                    ),
                  ),
                  Text(
                    "Day: $selectedDay",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            LineIcons.stickyNote,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No notes added yet",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your first day-to-day note above",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}