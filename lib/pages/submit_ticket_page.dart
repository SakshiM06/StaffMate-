import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:line_icons/line_icons.dart';

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
  static const Color fieldFillColor = Color(0xFFE8EAF6);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color openStatusColor = Color(0xFF2196F3);
  static const Color inProgressColor = Color(0xFFFF9800);
  static const Color resolvedColor = Color(0xFF4CAF50);
  static const Color closedColor = Color(0xFF9E9E9E);
  static const Color highPriorityColor = Color(0xFFE53935);
  static const Color mediumPriorityColor = Color(0xFFFF9800);
  static const Color lowPriorityColor = Color(0xFF4CAF50);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
}

class SubmitTicketPage extends StatefulWidget {
  const SubmitTicketPage({super.key});

  @override
  State<SubmitTicketPage> createState() => _SubmitTicketPageState();
}

class _SubmitTicketPageState extends State<SubmitTicketPage> {
  // --- STATE MANAGEMENT ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();

  String _selectedCategory = 'IT Issue';
  String _selectedPriority = 'Medium';
  String _selectedLanguage = 'English';
  String _selectedStatus = 'Open';
  String _selectedTicketType = 'Open Tickets';
  String _selectedTicketView = 'Create Ticket';
  
  File? _selectedImage;
  List<String> _comments = [];
  List<Map<String, dynamic>> _openTickets = [];
  List<Map<String, dynamic>> _closedTickets = [];
  List<Map<String, dynamic>> _allTickets = [];

  final List<String> _categories = ['IT Issue', 'System Issue', 'Billing Error', 'Hardware', 'Software', 'Network', 'Other'];
  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];
  final List<String> _languages = ['English', 'Hindi', 'Marathi', 'Gujarati', 'Tamil'];
  final List<String> _statuses = ['Open', 'In Progress', 'Resolved', 'Closed'];
  final List<String> _ticketViews = ['Create Ticket', 'Ticket List', 'Ticket Details'];

  late stt.SpeechToText _speech;
  bool _isListening = false;
  int _selectedTicketIndex = -1;

  // --- LIFECYCLE & CORE METHODS ---
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermissions();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    // Sample open tickets
    _openTickets = [
      {
        'id': 'TKT-001',
        'title': 'Login Issue',
        'category': 'IT Issue',
        'priority': 'High',
        'status': 'In Progress',
        'date': '2024-01-15',
        'description': 'Unable to login to the system',
        'language': 'English',
      },
      {
        'id': 'TKT-002',
        'title': 'Printer Not Working',
        'category': 'Hardware',
        'priority': 'Medium',
        'status': 'Open',
        'date': '2024-01-16',
        'description': 'Office printer not responding',
        'language': 'English',
      },
      {
        'id': 'TKT-004',
        'title': 'Software License Expired',
        'category': 'Software',
        'priority': 'Medium',
        'status': 'Open',
        'date': '2024-01-18',
        'description': 'Adobe license needs renewal',
        'language': 'English',
      },
    ];

    // Sample closed tickets
    _closedTickets = [
      {
        'id': 'TKT-003',
        'title': 'Email Configuration',
        'category': 'Software',
        'priority': 'Low',
        'status': 'Resolved',
        'date': '2024-01-10',
        'description': 'Email setup issue',
        'resolution': 'Updated SMTP settings and verified connectivity',
        'language': 'English',
      },
      {
        'id': 'TKT-005',
        'title': 'Network Connectivity',
        'category': 'Network',
        'priority': 'High',
        'status': 'Closed',
        'date': '2024-01-05',
        'description': 'No internet access in Conference Room',
        'resolution': 'Router replaced and cables checked',
        'language': 'English',
      },
    ];

    // Combine all tickets
    _allTickets = [..._openTickets, ..._closedTickets];

    // Sample comments for selected ticket
    _comments = [
      'User reported login issue at 10:30 AM',
      'IT team is investigating the problem',
      'Waiting for user response with screenshots',
    ];
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.photos.request();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() => _descController.text = val.recognizedWords),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _addComment() {
    if (_commentController.text.isNotEmpty) {
      setState(() {
        _comments.add('${DateTime.now().hour}:${DateTime.now().minute} - ${_commentController.text}');
        _commentController.clear();
      });
    }
  }

  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      final newTicket = {
        'id': 'TKT-00${_openTickets.length + _closedTickets.length + 1}',
        'title': _titleController.text,
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'status': 'Open',
        'date': DateTime.now().toString().split(' ')[0],
        'description': _descController.text,
        'language': _selectedLanguage,
      };

      setState(() {
        _openTickets.insert(0, newTicket);
        _allTickets = [..._openTickets, ..._closedTickets];
        _selectedTicketView = 'Ticket List';
        _selectedTicketType = 'Open Tickets';
        _selectedTicketIndex = 0;
        _selectedStatus = 'Open';
        _resolutionController.clear();
        _comments = [
          'Ticket created on ${DateTime.now().toString().split(' ')[0]}',
          'Assigned to IT Support Team',
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ticket ${newTicket['id']} submitted successfully!"),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      _titleController.clear();
      _descController.clear();
      setState(() => _selectedImage = null);
    }
  }

  void _resolveTicket() {
    if (_selectedTicketIndex >= 0 && _resolutionController.text.isNotEmpty) {
      final ticket = _openTickets[_selectedTicketIndex];
      setState(() {
        ticket['status'] = 'Resolved';
        ticket['resolution'] = _resolutionController.text;
        _closedTickets.insert(0, ticket);
        _openTickets.removeAt(_selectedTicketIndex);
        _allTickets = [..._openTickets, ..._closedTickets];
        _selectedTicketIndex = -1;
        _selectedTicketType = 'Closed Tickets';
        _selectedTicketView = 'Ticket List';
        _resolutionController.clear();
        _comments.add('Ticket resolved on ${DateTime.now().toString().split(' ')[0]}');
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ticket ${ticket['id']} resolved successfully!"),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'high':
        return AppColors.highPriorityColor;
      case 'medium':
        return AppColors.mediumPriorityColor;
      case 'low':
        return AppColors.lowPriorityColor;
      default:
        return AppColors.textBodyColor;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.openStatusColor;
      case 'in progress':
        return AppColors.inProgressColor;
      case 'resolved':
        return AppColors.resolvedColor;
      case 'closed':
        return AppColors.closedColor;
      default:
        return AppColors.textBodyColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.lock_open_rounded;
      case 'in progress':
        return Icons.schedule_rounded;
      case 'resolved':
        return Icons.check_circle_rounded;
      case 'closed':
        return Icons.lock_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      appBar: AppBar(
        title: Text(
          "Submit Ticket",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primaryDarkBlue,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(LineIcons.history, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedTicketView = 'Ticket List';
                _selectedTicketIndex = -1;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // View Selector Tabs - COMPACT DESIGN
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: _ticketViews.map((view) {
                final isSelected = _selectedTicketView == view;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTicketView = view;
                        if (view != 'Ticket Details') {
                          _selectedTicketIndex = -1;
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryDarkBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryDarkBlue : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          view,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSelectedView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedView() {
    switch (_selectedTicketView) {
      case 'Create Ticket':
        return _buildCreateTicketView();
      case 'Ticket List':
        return _buildTicketListView();
      case 'Ticket Details':
        return _buildTicketDetailsView();
      default:
        return _buildCreateTicketView();
    }
  }

  // 2.3.1 Create Ticket View
  Widget _buildCreateTicketView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Create New Ticket',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
            ),

            // Ticket Title
            _buildCompactTextField(
              controller: _titleController,
              label: 'Ticket Title',
              icon: Icons.title_rounded,
              hintText: 'Enter ticket title',
              validator: (value) => value!.isEmpty ? 'Please enter ticket title' : null,
            ),
            const SizedBox(height: 12),

            // Category & Priority in one row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactDropdown(
                    label: 'Priority',
                    value: _selectedPriority,
                    items: _priorities,
                    onChanged: (value) => setState(() => _selectedPriority = value!),
                    showColorIndicator: true,
                    getColor: _getPriorityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Language
            _buildCompactDropdown(
              label: 'Language',
              value: _selectedLanguage,
              items: _languages,
              onChanged: (value) => setState(() => _selectedLanguage = value!),
            ),
            const SizedBox(height: 12),

            // Description
            _buildCompactTextArea(
              controller: _descController,
              label: 'Description',
              hintText: 'Describe your issue in detail...',
              validator: (value) => value!.isEmpty ? 'Please enter description' : null,
              isListening: _isListening,
              onMicPressed: _listen,
            ),
            const SizedBox(height: 12),

            // Attachment
            _buildCompactAttachmentField(),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 1,
                ),
                child: Text(
                  'Submit Ticket',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 2.3.2 Ticket List View
  Widget _buildTicketListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            'Ticket List',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.primaryDarkBlue,
            ),
          ),
        ),

        // Ticket Type Tabs
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactTabButton('Open Tickets', _selectedTicketType == 'Open Tickets'),
              ),
              Expanded(
                child: _buildCompactTabButton('Closed Tickets', _selectedTicketType == 'Closed Tickets'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ticket Count Cards
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactCountCard('Total', _allTickets.length.toString(), AppColors.primaryDarkBlue),
              _buildCompactCountCard('Open', _openTickets.length.toString(), AppColors.openStatusColor),
              _buildCompactCountCard('Progress', _openTickets.where((t) => t['status'] == 'In Progress').length.toString(), AppColors.inProgressColor),
              _buildCompactCountCard('Resolved', _closedTickets.where((t) => t['status'] == 'Resolved').length.toString(), AppColors.resolvedColor),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tickets List
        Expanded(
          child: _openTickets.isEmpty && _closedTickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: AppColors.grey400, size: 50),
                      const SizedBox(height: 12),
                      Text(
                        'No tickets found',
                        style: GoogleFonts.poppins(
                          color: AppColors.grey500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _selectedTicketType == 'Open Tickets' ? _openTickets.length : _closedTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _selectedTicketType == 'Open Tickets' ? _openTickets[index] : _closedTickets[index];
                    final isSelected = _selectedTicketIndex == index && _selectedTicketView == 'Ticket Details';
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTicketIndex = index;
                          _selectedTicketView = 'Ticket Details';
                          // Reset comments for demo purposes
                          _comments = [
                            'Ticket created on ${ticket['date']}',
                            'Priority: ${ticket['priority']}',
                            'Category: ${ticket['category']}',
                            if (_selectedTicketType == 'Closed Tickets' && ticket['resolution'] != null)
                              'Resolution: ${ticket['resolution']}'
                          ];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryDarkBlue.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryDarkBlue : AppColors.grey200,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ticket Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket['title'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(ticket['priority']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _getPriorityColor(ticket['priority']).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    ticket['priority'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: _getPriorityColor(ticket['priority']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Ticket ID and Status
                            Row(
                              children: [
                                Text(
                                  ticket['id'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: AppColors.primaryDarkBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(ticket['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getStatusIcon(ticket['status']),
                                        size: 10,
                                        color: _getStatusColor(ticket['status']),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        ticket['status'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(ticket['status']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  ticket['date'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.grey500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Category
                            Row(
                              children: [
                                Icon(Icons.category_outlined, size: 12, color: AppColors.textBodyColor),
                                const SizedBox(width: 4),
                                Text(
                                  ticket['category'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textBodyColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 2.3.3 Ticket Details View
  Widget _buildTicketDetailsView() {
    if (_selectedTicketIndex < 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.grey400, size: 50),
            const SizedBox(height: 12),
            Text(
              'Select a ticket to view details',
              style: GoogleFonts.poppins(
                color: AppColors.grey500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final ticketList = _selectedTicketType == 'Open Tickets' ? _openTickets : _closedTickets;
    if (_selectedTicketIndex >= ticketList.length) {
      return Center(
        child: Text(
          'Ticket not found',
          style: GoogleFonts.poppins(color: AppColors.grey500),
        ),
      );
    }

    final ticket = ticketList[_selectedTicketIndex];
    final isOpenTicket = _selectedTicketType == 'Open Tickets';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Ticket Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.primaryDarkBlue,
              ),
            ),
          ),

          // Ticket Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Title
                Text(
                  ticket['title'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),

                // Ticket ID and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ticket['id'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(ticket['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _getStatusColor(ticket['status']).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(_getStatusIcon(ticket['status']), size: 12, color: _getStatusColor(ticket['status'])),
                          const SizedBox(width: 5),
                          Text(
                            ticket['status'],
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(ticket['status']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details Grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCompactDetailItem('Category', ticket['category'], Icons.category_rounded),
                    _buildCompactDetailItem('Priority', ticket['priority'], Icons.priority_high_rounded),
                    _buildCompactDetailItem('Language', ticket['language'], Icons.language_rounded),
                    _buildCompactDetailItem('Date', ticket['date'], Icons.calendar_today_rounded),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Description',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket['description'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Comments Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.comment_rounded, color: AppColors.primaryDarkBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Add Comment
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.grey300),
                        ),
                        child: TextField(
                          controller: _commentController,
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: GoogleFonts.poppins(color: AppColors.grey500, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDarkBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Comments List
                if (_comments.isNotEmpty)
                  ..._comments.map((comment) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDarkBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              comment,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  Center(
                    child: Text(
                      'No comments yet',
                      style: GoogleFonts.poppins(
                        color: AppColors.grey500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Resolution Section (for open tickets) or Resolution Display (for closed)
          if (isOpenTicket)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.task_alt_rounded, color: AppColors.successGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add Resolution',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _resolutionController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter resolution details...',
                      hintStyle: GoogleFonts.poppins(color: AppColors.grey500, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.grey100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resolveTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 1,
                      ),
                      child: Text(
                        'Mark as Resolved',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (ticket['resolution'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Resolution',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      ticket['resolution']!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Compact Helper Widgets
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    required String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.grey300),
          ),
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 13),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(color: AppColors.grey500, fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.primaryDarkBlue, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTextArea({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?)? validator,
    required bool isListening,
    required VoidCallback onMicPressed,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            IconButton(
              onPressed: onMicPressed,
              icon: Icon(
                isListening ? Icons.mic_off : Icons.mic,
                color: isListening ? AppColors.errorRed : AppColors.primaryDarkBlue,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.grey300),
          ),
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 13),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(color: AppColors.grey500, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    bool showColorIndicator = false,
    Color Function(String)? getColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            _showCompactBottomSheet(
              context: context,
              title: label,
              items: items,
              currentValue: value,
              onSelected: onChanged,
              showColorIndicator: showColorIndicator,
              getColor: getColor,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.grey300),
            ),
            child: Row(
              children: [
                if (showColorIndicator && getColor != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: getColor(value),
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: AppColors.grey500, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAttachmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachment',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.grey300, width: 1.2),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.grey400, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to add screenshot',
                        style: GoogleFonts.poppins(color: AppColors.grey500, fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTabButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTicketType = text;
          _selectedTicketIndex = -1;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDarkBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCountCard(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textBodyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDetailItem(String label, String value, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 40) / 2,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textBodyColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textBodyColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompactBottomSheet({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String currentValue,
    required Function(String?) onSelected,
    bool showColorIndicator = false,
    Color Function(String)? getColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...items.map((item) {
                        return GestureDetector(
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: currentValue == item ? AppColors.primaryDarkBlue.withOpacity(0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: currentValue == item ? AppColors.primaryDarkBlue : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                if (showColorIndicator && getColor != null)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: getColor(item),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: currentValue == item ? AppColors.primaryDarkBlue : AppColors.textDark,
                                    ),
                                  ),
                                ),
                                if (currentValue == item)
                                  Icon(Icons.check_rounded, color: AppColors.primaryDarkBlue, size: 18),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.grey100,
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}