import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/message_model.dart';
import '../ai/ticket_model.dart';
import 'package:staff_mate/services/forgetpassword_service.dart';
import 'package:staff_mate/services/support_service.dart';
import 'dart:convert';

class ChatService {
  final ForgetPasswordService _passwordService = ForgetPasswordService();
  final Map<String, Map<String, dynamic>> _resetSessions = {};
  
  // FAQ questions list for detection - Updated with 12 questions
  static const List<String> _faqQuestions = [
    '📅 Where can I view my work schedule?',
    '👥 How can I check the staff rota?',
    '✅ How can I see my assigned tasks?',
    '📋 How can I add a new task?',
    '📌 How can I view today\'s tasks?',
    '📅 How can I check upcoming tasks?',
    '✔️ How can I see completed tasks?',
    '🔄 How can I update the status of a task?',
    '📝 How can I add a handover note?',
    '👁️ How can I view handover notes?',
    '🏥 How can I shift a patient to another ward?',
    '@ How can I tag a colleague in a handover note?',
  ];
  
  /// Get chat history - returns welcome message with options including FAQ
  Future<List<MessageModel>> getChatHistory() async {
    debugPrint('📱 Loading chat history');
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      MessageModel(
        id: 'welcome_1',
        text: '👋 Hello! I\'m your SmartCare support assistant. Please choose an option:',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        type: 'welcome',
        quickReplies: const [
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🔐 Forgot Password',
          '📚 FAQ',
        ],
      ),
      MessageModel(
        id: 'contact_1',
        text: '📞 You can also call us at:\n☎️ 94040 22226\n☎️ 94040 22288',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        type: 'contact',
        quickReplies: const [
          '📞 Call 94040 22226',
          '📞 Call 94040 22288',
        ],
      ),
    ];
  }

  // ============== PUBLIC METHODS FOR CHAT PROVIDER ==============
  
  /// Validate email using the password service
  bool isValidEmail(String email) {
    return _passwordService.isValidEmail(email);
  }

  /// Validate OTP using the password service
  bool isValidOTP(String otp) {
    return _passwordService.isValidOTP(otp);
  }

  /// Generate a strong password
  String generateStrongPassword() {
    return _generateStrongPassword();
  }

  /// Validate password using the password service
  Map<String, dynamic> validatePassword(String password) {
    return _passwordService.validatePassword(password);
  }

  /// Get FAQ answer for a question - Updated with 12 StaffMate answers
  String _getFaqAnswer(String question) {
    final faqAnswers = {
      // Scheduling & Rota
      '📅 Where can I view my work schedule?': 
          '📅 **View Work Schedule**\n\n'
          'Navigate to the **Schedule** or **My Roster** section on the home screen or from the main menu.\n\n'
          'You can view it by:\n'
          '• 📆 **Day view** - See today\'s schedule\n'
          '• 📅 **Week view** - View entire week\n'
          '• 📊 **Month view** - Overview of all shifts',
      
      '👥 How can I check the staff rota?': 
          '👥 **Staff Rota**\n\n'
          'Go to **Rota** > **Team View**.\n\n'
          'You can filter by:\n'
          '• 🏢 **Department** - View specific teams\n'
          '• 👤 **Role** - Filter by job role\n'
          '• 📅 **Date range** - Select custom dates\n\n'
          'The rota shows who is scheduled for each shift.',
      
      '✅ How can I see my assigned tasks?': 
          '✅ **Assigned Tasks**\n\n'
          'Your assigned tasks appear on the **Dashboard** under "My Tasks" or "Today\'s Duties."\n\n'
          'You can:\n'
          '• 👆 Tap any task to view full details\n'
          '• 📝 Update task status\n'
          '• 📎 View attachments\n'
          '• 💬 Add comments',
      
      // Tasks & Management
      '📋 How can I add a new task?': 
          '📋 **Add New Task**\n\n'
          '1. Go to **Tasks** > **Add New Task**\n'
          '2. Fill in the details:\n'
          '   • 📝 Title and description\n'
          '   • 👤 Assignee\n'
          '   • ⚡ Priority (Low/Medium/High)\n'
          '   • 📅 Due date & time\n'
          '3. Tap **Save** or **Assign**\n\n'
          '✅ The assignee will receive a notification.',
      
      '📌 How can I view today\'s tasks?': 
          '📌 **Today\'s Tasks**\n\n'
          'There are several ways:\n\n'
          '1️⃣ **Quick View**\n'
          '   Check the **Dashboard** widget for today\'s tasks\n\n'
          '2️⃣ **Tasks Module**\n'
          '   Go to **Tasks** and select the **Today** filter\n\n'
          '3️⃣ **Notifications**\n'
          '   Check your notification center for pending tasks\n\n'
          '📊 Tasks are color-coded by priority and status.',
      
      '📅 How can I check upcoming tasks?': 
          '📅 **Upcoming Tasks**\n\n'
          'View future tasks:\n\n'
          '📱 **Via Tasks Section**\n'
          '• Go to **Tasks** > **Upcoming** filter\n'
          '• Shows tasks scheduled for future dates\n\n'
          '🗓️ **Via Calendar View**\n'
          '• Switch to **Calendar** view\n'
          '• See tasks spread across dates\n\n'
          '🔔 You\'ll receive reminders before tasks are due.',
      
      '✔️ How can I see completed tasks?': 
          '✔️ **Completed Tasks**\n\n'
          'View your task history:\n\n'
          '• Go to **Tasks** > **History**\n'
          '• Select the **Completed** filter\n\n'
          'You can see:\n'
          '✅ Completed date & time\n'
          '👤 Who completed the task\n'
          '📝 Completion notes\n\n'
          '📊 Use this to track your productivity!',
      
      '🔄 How can I update the status of a task?': 
          '🔄 **Update Task Status**\n\n'
          '1. Open the task detail page\n'
          '2. Tap the **Status** dropdown\n'
          '3. Select new status:\n'
          '   • ⏳ Pending\n'
          '   • 🔄 In Progress\n'
          '   • ✅ Completed\n'
          '   • ❌ Cancelled\n'
          '4. Add completion notes (optional)\n'
          '5. Confirm update\n\n'
          '📢 Status changes notify the task creator.',
      
      // Handover & Communication
      '📝 How can I add a handover note?': 
          '📝 **Add Handover Note**\n\n'
          'Navigate to the **Handover** or **Patient List** section.\n\n'
          '1. Select the patient\n'
          '2. Tap **Add Handover Note**\n'
          '3. Enter the details for the incoming shift\n'
          '4. Tap **Save**\n\n'
          'The handover note will be visible to the next shift.',
      
      '👁️ How can I view handover notes?': 
          '👁️ **View Handover Notes**\n\n'
          'Go to **Handover** > **Shift Summary**.\n\n'
          'Select the relevant date and shift to view:\n'
          '• 📋 All handover notes\n'
          '• ⭐ Priority patients\n'
          '• ⏰ Pending tasks\n\n'
          'Notes shared by the outgoing team will appear here.',
      
      '🏥 How can I shift a patient to another ward?': 
          '🏥 **Shift Patient to Another Ward/Bed**\n\n'
          'If using the bed management module:\n\n'
          '1. Go to **Bed Management** or **Patient Tracking**\n'
          '2. Select the patient\n'
          '3. Choose **Transfer**\n'
          '4. Select the new ward and bed number\n'
          '5. Confirm the transfer\n\n'
          'The patient\'s location will be updated in the system.',
      
      '@ How can I tag a colleague in a handover note?': 
          '@ **Tag a Colleague in Handover Note**\n\n'
          'While creating or editing a handover note:\n\n'
          '1. Type **@** followed by the colleague\'s name\n'
          '2. Select the colleague from the dropdown\n'
          '3. Continue typing your note\n\n'
          '✅ They will receive a notification to ensure critical information is directly communicated.',
    };
    
    return faqAnswers[question] ?? 
        '📚 I don\'t have an answer for that question yet.\n\n'
        'Please try:\n'
        '• Rephrasing your question\n'
        '• Typing "FAQ" to see all options\n'
        '• Contacting support for more help';
  }

  /// Show FAQ menu - Updated with 12 questions
  MessageModel _getFaqMenu() {
    return MessageModel(
      id: DateTime.now().toString(),
      text: '📚 **Frequently Asked Questions**\n\nSelect a question to get instant help:',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'faq_menu',
      quickReplies: const [
        '📅 Where can I view my work schedule?',
        '👥 How can I check the staff rota?',
        '✅ How can I see my assigned tasks?',
        '📋 How can I add a new task?',
        '📌 How can I view today\'s tasks?',
        '📅 How can I check upcoming tasks?',
        '✔️ How can I see completed tasks?',
        '🔄 How can I update the status of a task?',
        '📝 How can I add a handover note?',
        '👁️ How can I view handover notes?',
        '🏥 How can I shift a patient to another ward?',
        '@ How can I tag a colleague in a handover note?',
        '🏠 Main Menu',
      ],
    );
  }

  /// Process selected option
  Future<MessageModel?> processOption(String option, {String? sessionId}) async {
    debugPrint('📱 Option selected: "$option"');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final cleanOption = option.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    
    // ─── FAQ HANDLING ─────────────────────────────────────────────────────────
    // Handle FAQ menu request
    if (option == '📚 FAQ' || 
        option == 'FAQ' || 
        cleanOption == 'faq' ||
        cleanOption == 'faqs') {
      return _getFaqMenu();
    }
    
    // Handle More FAQs
    if (option == '📚 More FAQs' || option == 'More FAQs') {
      return _getFaqMenu();
    }
    
    // Handle individual FAQ questions
    if (_faqQuestions.contains(option)) {
      final answer = _getFaqAnswer(option);
      return MessageModel(
        id: DateTime.now().toString(),
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
        type: 'faq_answer',
        quickReplies: const [
          '📚 More FAQs',
          '🏠 Main Menu',
        ],
      );
    }
    
    // ─── MAIN MENU OPTIONS ────────────────────────────────────────────────────
    if (cleanOption.contains('create ticket') || option == '🎫 Create Ticket') {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '📝 **Create Support Ticket**\n\nPlease fill in the form below:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_form',
        formField: 'ticket_creation',
        tempData: {'showForm': true},
        quickReplies: const [],
      );
    }

    // Handle "Create Another" after ticket creation
    else if (option == '🎫 Create Another') {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '📝 **Create Another Ticket**\n\nPlease fill in the form below:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_form',
        formField: 'ticket_creation',
        tempData: {'showForm': true},
        quickReplies: const [],
      );
    }

    // Handle "View My Tickets"
    else if (option == '📋 View My Tickets' || 
             cleanOption.contains('view my tickets') || 
             cleanOption.contains('view tickets') ||
             cleanOption.contains('my tickets')) {
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '📋 **View Tickets by Status**\n\nPlease select a status to view tickets:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'status_selection',
        tempData: {'action': 'view_tickets_by_status'},
        quickReplies: const [
          '📋 OPEN Tickets',
          '📋 IN_PROGRESS Tickets',
          '📋 RESOLVED Tickets',
          '📋 CLOSED Tickets',
          '🏠 Main Menu',
        ],
      );
    }
    
    // Handle View Tickets by Status
    else if (option.startsWith('📋 ') && option.contains('Tickets')) {
      final status = option
          .replaceAll('📋 ', '')
          .replaceAll(' Tickets', '')
          .trim();
      
      debugPrint('📋 Fetching tickets with status: $status');
      return await _getTicketsByStatus(status);
    }
    
    // Handle Track Tickets - Main option
    else if (option == '🔍 Track Ticket' || 
             cleanOption.contains('track ticket') ||
             cleanOption.contains('track')) {
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '🔍 **Track Tickets by Status**\n\nPlease select a status to track tickets:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'status_selection',
        tempData: {'action': 'track_tickets_by_status'},
        quickReplies: const [
          '🔍 OPEN Tickets',
          '🔍 IN_PROGRESS Tickets',
          '🔍 RESOLVED Tickets',
          '🔍 CLOSED Tickets',
          '🏠 Main Menu',
        ],
      );
    }
    
    // Handle Track Specific Ticket from list
    else if (option.startsWith('🔍 Track #')) {
      final ticketId = option.replaceAll('🔍 Track #', '').trim();
      return await _handleTrackTicket(ticketId);
    }
    
    // Handle View Specific Ticket - GET API call
    else if (option.startsWith('🔍 View Ticket #')) {
      final ticketId = option.replaceAll('🔍 View Ticket #', '').trim();
      return await _handleViewTicket(ticketId);
    }
    
    // Handle Update Status
    else if (option.startsWith('✏️ Update Status for #')) {
      final ticketId = option.replaceAll('✏️ Update Status for #', '').trim();
      return await _handleUpdateStatus(ticketId);
    }
    
    // Handle Status Selection - UPDATE API call
    else if (option.startsWith('✅ Set Status:') || 
             option.startsWith('⏳ Set Status:') || 
             option.startsWith('🔒 Set Status:') || 
             option.startsWith('🔄 Set Status:')) {
      
      final parts = option.split(' for #');
      if (parts.length == 2) {
        String status = parts[0]
            .replaceAll('✅ Set Status:', '')
            .replaceAll('⏳ Set Status:', '')
            .replaceAll('🔒 Set Status:', '')
            .replaceAll('🔄 Set Status:', '')
            .trim();
        final ticketId = parts[1].trim();
        debugPrint('🎯 Status selected: $status for ticket #$ticketId');
        return await _handleUpdateTicketStatus(ticketId, status);
      }
      return null;
    }
    
    // Handle Update Resolution Summary
    else if (option.startsWith('📝 Add Resolution for #')) {
      final ticketId = option.replaceAll('📝 Add Resolution for #', '').trim();
      return MessageModel(
        id: DateTime.now().toString(),
        text: '✏️ **Enter Resolution Summary**\n\nPlease type the resolution details for ticket #$ticketId:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'resolution_input',
        inputType: 'resolution_summary',
        tempData: {'ticketId': ticketId},
        quickReplies: const ['❌ Cancel', '🏠 Main Menu'],
      );
    }
    
    // Handle View Image - GET API call
    else if (option.startsWith('🖼️ View Image for #')) {
      final parts = option.replaceAll('🖼️ View Image for #', '').split(':');
      if (parts.length == 2) {
        final ticketId = parts[0].trim();
        final fileType = parts[1].trim().toLowerCase();
        return await _handleViewImage(ticketId, fileType);
      }
      return null;
    }
    
    // STEP 1: FORGOT PASSWORD - Automatically use credentials from SharedPreferences
    else if (cleanOption.contains('forgot password') || 
             cleanOption.contains('reset password') || 
             cleanOption.contains('forget password') ||
             option == '🔐 Forgot Password') {
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? '';
        final email = prefs.getString('otp_email')?.isNotEmpty == true
            ? prefs.getString('otp_email')!
            : prefs.getString('email') ?? '';
        
        debugPrint('📱 Retrieved from SharedPreferences - UserId: $userId, Email: $email');
        
        if (userId.isEmpty || email.isEmpty) {
          return MessageModel(
            id: DateTime.now().toString(),
            text: '❌ User information not found. Please ensure you are logged in properly or contact support.',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'error',
            quickReplies: const [
              '🏠 Main Menu',
            ],
          );
        }

        final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
        debugPrint('📱 Creating new session: $newSessionId');
        
        _resetSessions[newSessionId] = {
          'step': 'sending_otp',
          'sessionId': newSessionId,
          'userId': userId,
          'email': email,
          'createdAt': DateTime.now().toString(),
        };
        
        final result = await _passwordService.sendEmailOTP(
          email: email,
          userId: userId,
        );
        
        if (result['success'] == true) {
          _resetSessions[newSessionId] = {
            ..._resetSessions[newSessionId]!,
            'step': 'enter_otp',
          };
          
          await _passwordService.saveResetData(
            email: email,
            userId: userId,
          );
          
          return MessageModel(
            id: DateTime.now().toString(),
            text: '✅ OTP has been sent to $email\n\nPlease enter the 6-digit OTP:',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'password_reset',
            inputType: 'otp',
            tempData: {
              'step': 'enter_otp',
              'userId': userId,
              'email': email,
              'sessionId': newSessionId
            },
            quickReplies: const [
              '🔄 Resend OTP',
              '❌ Cancel',
              '🏠 Main Menu',
            ],
          );
        } else {
          String errorMessage = result['message'] ?? 'Failed to send OTP';
          
          return MessageModel(
            id: DateTime.now().toString(),
            text: '❌ $errorMessage\n\nPlease try again.',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'error',
            quickReplies: const [
              '🔄 Try Again',
              '🏠 Main Menu',
            ],
          );
        }
        
      } catch (e) {
        debugPrint('❌ Error retrieving user data: $e');
        return MessageModel(
          id: DateTime.now().toString(),
          text: '❌ Failed to retrieve user information. Please try again or contact support.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'error',
          quickReplies: const [
            '🏠 Main Menu',
          ],
        );
      }
    }
    
    // Handle Resend OTP
    else if (option == '🔄 Resend OTP') {
      if (sessionId != null && _resetSessions.containsKey(sessionId)) {
        final session = _resetSessions[sessionId]!;
        final userId = session['userId'] as String? ?? '';
        final email = session['email'] as String? ?? '';
        
        if (userId.isNotEmpty && email.isNotEmpty) {
          final result = await _passwordService.sendEmailOTP(
            email: email,
            userId: userId,
          );
          
          if (result['success'] == true) {
            return MessageModel(
              id: DateTime.now().toString(),
              text: '✅ OTP has been resent to $email\n\nPlease enter the 6-digit OTP:',
              isUser: false,
              timestamp: DateTime.now(),
              type: 'password_reset',
              inputType: 'otp',
              tempData: {
                'step': 'enter_otp',
                'userId': userId,
                'email': email,
                'sessionId': sessionId
              },
              quickReplies: const [
                '🔄 Resend OTP',
                '❌ Cancel',
                '🏠 Main Menu',
              ],
            );
          } else {
            return MessageModel(
              id: DateTime.now().toString(),
              text: '❌ Failed to resend OTP. Please try again.',
              isUser: false,
              timestamp: DateTime.now(),
              type: 'error',
              quickReplies: const [
                '🔄 Try Again',
                '🏠 Main Menu',
              ],
            );
          }
        }
      }
      return null;
    }
    
    // Handle Cancel
    else if (cleanOption.contains('cancel')) {
      if (sessionId != null) {
        _resetSessions.remove(sessionId);
        debugPrint('📱 Session cancelled and removed: $sessionId');
      }
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Action cancelled. Returning to main menu:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'welcome',
        quickReplies: const [
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🔐 Forgot Password',
          '📚 FAQ',
        ],
      );
    }
    
    // Handle Try Again
    else if (cleanOption.contains('try again')) {
      return MessageModel(
        id: DateTime.now().toString(),
        text: 'Let\'s try again. What would you like to do?',
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🔐 Forgot Password',
          '📚 FAQ',
        ],
      );
    }
    
    // Handle Back to Main Menu
    else if (cleanOption.contains('main menu') || cleanOption.contains('back to main menu') || option == '🏠 Main Menu') {
      if (sessionId != null) {
        _resetSessions.remove(sessionId);
        debugPrint('📱 Session cleared for main menu: $sessionId');
      }
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '👋 **Main Menu** - Please choose an option:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'welcome',
        quickReplies: const [
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🔐 Forgot Password',
          '📚 FAQ',
        ],
      );
    }
    
    // Handle Create New Ticket (from empty state)
    else if (option == '🎫 Create New Ticket') {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '📝 **Create Support Ticket**\n\nPlease fill in the form below:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_form',
        formField: 'ticket_creation',
        tempData: {'showForm': true},
        quickReplies: const [],
      );
    }
    
    // Default response for unrecognized options
    else {
      return MessageModel(
        id: DateTime.now().toString(),
        text: 'I didn\'t understand that option. Please choose from the menu:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'welcome',
        quickReplies: const [
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🔐 Forgot Password',
          '📚 FAQ',
        ],
      );
    }
  }

  /// Get tickets by status
  Future<MessageModel> _getTicketsByStatus(String status) async {
    try {
      debugPrint('📋 ===== GET TICKETS BY STATUS =====');
      debugPrint('Status: $status');
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        throw Exception('User ID not found');
      }
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final result = await SupportService.getTicketsByUserAndDate(
        userId: userId,
        date: today,
        status: status,
      );
      
      debugPrint('📊 API Response received: $result');
      
      List<TicketModel> tickets = [];
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        
        if (data['data'] != null && data['data'] is List) {
          debugPrint('📋 Found tickets in data["data"] as List');
          final List<dynamic> ticketsData = data['data'];
          tickets = ticketsData.map((json) => _parseTicketFromJson(json)).toList();
        } else if (data is List) {
          debugPrint('📋 Data is a direct List');
          tickets = data.map((json) => _parseTicketFromJson(json)).toList();
        }
        
        tickets = tickets.where((t) => t.statusText == status).toList();
        
        if (tickets.length > 10) {
          tickets = tickets.sublist(0, 10);
        }
      }
      
      if (tickets.isEmpty) {
        return MessageModel(
          id: DateTime.now().toString(),
          text: '📋 No **$status** tickets found.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'info',
          quickReplies: const [
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      } else {
        return MessageModel(
          id: DateTime.now().toString(),
          text: '📋 **$status Tickets** (Showing ${tickets.length} of 10)',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'ticket_list',
          tickets: tickets,
          quickReplies: const [
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching tickets by status: $e');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to fetch tickets: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Handle viewing a specific ticket - GET API call
  Future<MessageModel> _handleViewTicket(String ticketId) async {
    try {
      debugPrint('🔍 ===== VIEW TICKET =====');
      debugPrint('Ticket ID: $ticketId');
      
      final ticket = await getTicketDetails(ticketId);
      
      final hasUserImage = ticket.userFileName != null && ticket.userFileName!.isNotEmpty;
      final hasDevImage = ticket.developerFileName != null && ticket.developerFileName!.isNotEmpty;
      
      List<String> quickReplies = [
        '📋 View My Tickets',
        '🏠 Main Menu',
      ];
      
      if (hasUserImage) {
        quickReplies.insert(0, '🖼️ View Image for #${ticket.id}:user');
      }
      if (hasDevImage) {
        quickReplies.insert(hasUserImage ? 1 : 0, '🖼️ View Image for #${ticket.id}:developer');
      }
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '📋 **Ticket #${ticket.id} Details**\n\n'
              '**Title:** ${ticket.title}\n'
              '**Description:** ${ticket.description}\n'
              '**Status:** ${ticket.statusText}\n'
              '**Priority:** ${ticket.priorityText}\n'
              '**Created:** ${_formatDateTime(ticket.createdAt)}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_detail',
        ticket: ticket,
        quickReplies: quickReplies,
      );
    } catch (e) {
      debugPrint('❌ Error viewing ticket: $e');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to fetch ticket details: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Handle viewing ticket image - GET API call
  Future<MessageModel> _handleViewImage(String ticketId, String fileType) async {
    try {
      debugPrint('🖼️ ===== VIEW IMAGE =====');
      debugPrint('Ticket ID: $ticketId, Type: $fileType');
      
      final result = await SupportService.viewTicketImageBase64(
        ticketId: int.tryParse(ticketId) ?? 0,
        fileType: fileType.toUpperCase(),
      );
      
      if (result['success'] == true && result['data'] != null && result['data']['imageBase64'] != null) {
        final base64String = result['data']['imageBase64'];
        final imageBytes = base64Decode(base64String);
        final fileName = result['data']['fileName'] ?? 'image.jpg';
        final fileType_response = result['data']['fileType'] ?? fileType;
        
        debugPrint('✅ Image fetched successfully: ${imageBytes.length} bytes');
        
        return MessageModel(
          id: DateTime.now().toString(),
          text: '🖼️ **Ticket Image**\n\nTicket #$ticketId - ${fileType_response.toUpperCase()} Image\nFile: $fileName',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'ticket_image',
          imageData: imageBytes,
          imageMimeType: _getImageContentType(base64String),
          quickReplies: [
            '🔍 View Ticket #$ticketId',
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to load image';
        
        if (errorMessage.contains('File not found') || 
            errorMessage.contains('No image') ||
            result['status_code'] == 404 ||
            result['status_code'] == 400) {
          
          return MessageModel(
            id: DateTime.now().toString(),
            text: '📷 **No Image Available**\n\nNo ${fileType.toUpperCase()} image found for ticket #$ticketId.\n\nThis ticket may not have any attachments or the image may have been removed.',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'info',
            quickReplies: [
              '🔍 View Ticket #$ticketId',
              '📋 View My Tickets',
              '🏠 Main Menu',
            ],
          );
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Error loading image: $e');
      
      final errorMsg = e.toString();
      if (errorMsg.contains('File not found') || errorMsg.contains('404')) {
        return MessageModel(
          id: DateTime.now().toString(),
          text: '📷 **No Image Available**\n\nNo ${fileType.toUpperCase()} image found for ticket #$ticketId.\n\nThis ticket may not have any attachments or the image may have been removed.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'info',
          quickReplies: [
            '🔍 View Ticket #$ticketId',
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      }
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to load image: ${e.toString().replaceAll('Exception:', '')}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: [
          '🔍 View Ticket #$ticketId',
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  String _getImageContentType(String base64String) {
    if (base64String.startsWith('/9j/')) {
      return 'image/jpeg';
    } else if (base64String.startsWith('iVBOR')) {
      return 'image/png';
    } else if (base64String.startsWith('R0lGOD')) {
      return 'image/gif';
    } else if (base64String.startsWith('UklGR')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Handle tracking a specific ticket
  Future<MessageModel> _handleTrackTicket(String ticketId) async {
    try {
      debugPrint('🔍 ===== TRACK TICKET =====');
      debugPrint('Ticket ID: $ticketId');
      
      final ticket = await getTicketDetails(ticketId);
      
      String trackInfo = '🔍 **Ticket Tracking**\n\n';
      trackInfo += '**Ticket ID:** #${ticket.id}\n';
      trackInfo += '**Title:** ${ticket.title}\n';
      trackInfo += '**Description:** ${ticket.description}\n';
      trackInfo += '**Status:** ${ticket.statusText}\n';
      trackInfo += '**Priority:** ${ticket.priorityText}\n';
      trackInfo += '**Created:** ${_formatDateTime(ticket.createdAt)}\n';
      
      if (ticket.resolvedAt != null) {
        trackInfo += '**Resolved:** ${_formatDateTime(ticket.resolvedAt!)}\n';
      }
      
      if (ticket.closedDate != null) {
        trackInfo += '**Closed:** ${_formatDateTime(ticket.closedDate!)}\n';
      }
      
      if (ticket.currentResolutionSummary != null && ticket.currentResolutionSummary!.isNotEmpty) {
        trackInfo += '\n**Resolution Summary:**\n${ticket.currentResolutionSummary}\n';
      }
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: trackInfo,
        isUser: false,
        timestamp: DateTime.now(),
        type: 'track_ticket_detail',
        ticket: ticket,
        quickReplies: [
          '✏️ Update Status for #${ticket.id}',
          '📝 Add Resolution for #${ticket.id}',
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    } catch (e) {
      debugPrint('❌ Error tracking ticket: $e');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to fetch ticket details: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Handle update status selection
  Future<MessageModel> _handleUpdateStatus(String ticketId) async {
    return MessageModel(
      id: DateTime.now().toString(),
      text: '📋 **Select new status for ticket #$ticketId**',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'status_selection',
      tempData: {'ticketId': ticketId},
      quickReplies: const [
        '✅ Set Status: OPEN for #',
        '⏳ Set Status: IN_PROGRESS for #',
        '🔒 Set Status: RESOLVED for #',
        '🔄 Set Status: REOPENED for #',
        '❌ Cancel',
        '🏠 Main Menu',
      ],
    );
  }

  /// Handle updating ticket status - PUT API call
  Future<MessageModel> _handleUpdateTicketStatus(String ticketId, String newStatus) async {
    try {
      debugPrint('🔄 ===== UPDATE TICKET STATUS =====');
      debugPrint('Ticket ID: $ticketId');
      debugPrint('New Status: $newStatus');
      
      final ticket = await getTicketDetails(ticketId);
      
      debugPrint('Current ticket: ${ticket.title} (${ticket.statusText})');
      
      final intTicketId = int.tryParse(ticketId) ?? 0;
      if (intTicketId == 0) {
        throw Exception('Invalid ticket ID: $ticketId');
      }
      
      final result = await SupportService.updateTicket(
        ticketId: intTicketId,
        description: ticket.description,
        priority: ticket.priorityText,
        status: newStatus,
        currentResolutionSummary: ticket.currentResolutionSummary,
        queryType: '',
      );
      
      debugPrint('✅ Update API Response: $result');
      
      if (result['success'] == true) {
        final updatedTicket = await getTicketDetails(ticketId);
        
        return MessageModel(
          id: DateTime.now().toString(),
          text: '✅ **Status Updated Successfully!**\n\n'
                'Ticket #$ticketId status changed from **${ticket.statusText}** to **$newStatus**',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'track_ticket_detail',
          ticket: updatedTicket,
          quickReplies: [
            '🔍 Track Ticket #$ticketId',
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to update status: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔄 Try Again',
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Handle updating resolution summary - PUT API call
  Future<MessageModel> _handleUpdateResolutionSummary(String ticketId, String summary, String sessionId) async {
    try {
      debugPrint('📝 ===== UPDATE RESOLUTION SUMMARY =====');
      debugPrint('Ticket ID: $ticketId');
      debugPrint('Summary: $summary');
      
      final ticket = await getTicketDetails(ticketId);
      
      final result = await SupportService.updateTicket(
        ticketId: int.tryParse(ticketId) ?? 0,
        description: ticket.description,
        priority: ticket.priorityText,
        status: ticket.statusText,
        currentResolutionSummary: summary,
        queryType: '',
      );
      
      debugPrint('✅ Update API Response: $result');
      
      if (result['success'] == true) {
        _updateSession(sessionId, {'step': 'completed'});
        
        final updatedTicket = await getTicketDetails(ticketId);
        
        return MessageModel(
          id: DateTime.now().toString(),
          text: '✅ **Resolution Summary Added!**\n\n'
                'Ticket #$ticketId has been updated with resolution details.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'track_ticket_detail',
          ticket: updatedTicket,
          quickReplies: [
            '🔍 Track Ticket #$ticketId',
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to update resolution');
      }
    } catch (e) {
      debugPrint('❌ Error updating resolution: $e');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed to update resolution: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔄 Try Again',
          '📋 View My Tickets',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Format date time for display
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Process text input (for typing)
  Future<MessageModel?> processTextInput(String text, String inputType, Map<String, dynamic> sessionData) async {
    debugPrint('📱 Processing text input: "$text" of type: $inputType');
    debugPrint('📱 Session data received: $sessionData');
    
    final sessionId = sessionData['sessionId'];
    
    if (sessionId == null || !_resetSessions.containsKey(sessionId)) {
      debugPrint('📱 Session expired or not found: $sessionId');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Session expired. Please start over.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔐 Forgot Password',
          '🏠 Main Menu',
        ],
      );
    }
    
    switch (inputType) {
      case 'otp':
        return await _handleOtpInput(text, sessionId);
        
      case 'new_password':
      case 'new_password_input':
        return await _handlePasswordInput(text, sessionId);
        
      case 'resolution_summary':
        final ticketId = sessionData['ticketId'];
        if (ticketId != null) {
          return await _handleUpdateResolutionSummary(ticketId.toString(), text, sessionId);
        }
        return null;
        
      default:
        return null;
    }
  }

  /// Handle OTP input
  Future<MessageModel> _handleOtpInput(String otp, String sessionId) async {
    debugPrint('📱 Handling OTP input: $otp for session: $sessionId');
    
    final sessionData = _getSessionData(sessionId);
    final userId = sessionData?['userId'] ?? '';
    final email = sessionData?['email'] ?? '';
    
    if (userId.isEmpty || email.isEmpty) {
      debugPrint('📱 Session data missing userId or email');
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Session expired. Please start the password reset process again.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔐 Forgot Password',
          '🏠 Main Menu',
        ],
      );
    }
    
    if (!_passwordService.isValidOTP(otp)) {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ OTP must be 6 digits. Please try again:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'otp',
        tempData: {
          'step': 'enter_otp',
          'userId': userId,
          'email': email,
          'sessionId': sessionId
        },
        quickReplies: const [
          '🔄 Resend OTP',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
    }
    
    return MessageModel(
      id: DateTime.now().toString(),
      text: '✅ OTP validated. Verifying...',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'loading',
      inputType: 'verifying_otp',
      tempData: {
        'step': 'verifying_otp',
        'userId': userId,
        'email': email,
        'sessionId': sessionId,
        'otp': otp
      },
      validationError: null,
    );
  }

  /// Handle Password input
  Future<MessageModel> _handlePasswordInput(String password, String sessionId) async {
    debugPrint('📱 Handling Password input for session: $sessionId');
    
    final sessionData = _getSessionData(sessionId);
    final userId = sessionData?['userId'] ?? '';
    final email = sessionData?['email'] ?? '';
    
    if (userId.isEmpty || email.isEmpty) {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Session expired. Please start over.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔐 Forgot Password',
          '🏠 Main Menu',
        ],
      );
    }
    
    final validation = _passwordService.validatePassword(password);
    
    if (!validation['isValid']) {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Password requirements not met:\n• At least 6 characters\n• Uppercase & lowercase letters\n• At least one number\n\nPassword strength: ${_getStrengthText(validation['strength'])}\n\nPlease try again:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'new_password',
        tempData: {'step': 'enter_new_password', 'userId': userId, 'email': email, 'sessionId': sessionId},
        validationError: validation['errors'].join('\n'),
        quickReplies: const [
          '🔑 Generate Strong Password',
          '✏️ Type Password',
          '❌ Cancel',
        ],
      );
    }
    
    return MessageModel(
      id: DateTime.now().toString(),
      text: '✅ Password validated. Updating...',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'loading',
      tempData: {
        'step': 'updating_password',
        'userId': userId,
        'email': email,
        'sessionId': sessionId,
        'password': password
      },
      validationError: null,
    );
  }

  // Public method for ChatProvider to call for API operations
  Future<MessageModel> performApiOperation(String operation, Map<String, dynamic> params) async {
    debugPrint('📱 Performing API operation: $operation');
    
    switch (operation) {
      case 'sendOtp':
        return await _sendOtpAndRespond(
          email: params['email'],
          userId: params['userId'],
          sessionId: params['sessionId'],
          isResend: params['isResend'] ?? false,
        );
        
      case 'verifyOtp':
        return await _verifyOtpAndRespond(
          otp: params['otp'],
          userId: params['userId'],
          email: params['email'],
          sessionId: params['sessionId'],
        );
        
      case 'updatePassword':
        return await _updatePasswordAndRespond(
          password: params['password'],
          userId: params['userId'],
          email: params['email'],
          sessionId: params['sessionId'],
        );
        
      case 'resendOtp':
        return await _handleResendOtp(params['sessionId']);
        
      case 'generatePassword':
        return await _handleGeneratePassword(params['sessionId']);
        
      case 'useGeneratedPassword':
        return await _handleUseGeneratedPassword(params['sessionId']);
        
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  /// Send OTP API call
  Future<MessageModel> _sendOtpAndRespond({
    required String email,
    required String userId,
    required String sessionId,
    bool isResend = false,
  }) async {
    debugPrint('📱 Sending OTP to email: $email for user: $userId');
    
    final result = await _passwordService.sendEmailOTP(
      email: email,
      userId: userId,
    );
    
    if (result['success'] == true) {
      _updateSession(sessionId, {
        'step': 'enter_otp',
      });
      
      await _passwordService.saveResetData(
        email: email,
        userId: userId,
      );
      
      final action = isResend ? 'resent' : 'sent';
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '✅ OTP has been $action to $email\n\nPlease enter the 6-digit OTP:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'otp',
        tempData: {
          'step': 'enter_otp',
          'userId': userId,
          'email': email,
          'sessionId': sessionId
        },
        quickReplies: const [
          '🔄 Resend OTP',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
    } else {
      String errorMessage = result['message'] ?? 'Failed to send OTP';
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ $errorMessage\n\nPlease try again:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔄 Try Again',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Verify OTP API call
  Future<MessageModel> _verifyOtpAndRespond({
    required String otp,
    required String userId,
    required String email,
    required String sessionId,
  }) async {
    debugPrint('📱 Verifying OTP for user: $userId');
    
    final result = await _passwordService.verifyOTP(
      userOtp: otp,
      userId: userId,
    );
    
    if (result['success'] == true) {
      _updateSession(sessionId, {
        'step': 'enter_new_password',
        'otpVerified': true,
      });
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '✅ OTP Verified Successfully!\n\nEnter your new password:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'new_password',
        tempData: {
          'step': 'enter_new_password',
          'otpVerified': true,
          'userId': userId,
          'email': email,
          'sessionId': sessionId
        },
        quickReplies: const [
          '🔑 Generate Strong Password',
          '✏️ Type Password',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
    } else {
      String errorMessage = result['message'] ?? 'Invalid OTP';
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ $errorMessage\n\nPlease try again:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'otp',
        tempData: {
          'step': 'enter_otp',
          'userId': userId,
          'email': email,
          'sessionId': sessionId
        },
        quickReplies: const [
          '🔄 Resend OTP',
          '🔄 Try Again',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Update Password API call
  Future<MessageModel> _updatePasswordAndRespond({
    required String password,
    required String userId,
    required String email,
    required String sessionId,
  }) async {
    debugPrint('📱 Updating password for user: $userId');
    
    final result = await _passwordService.updatePassword(
      password: password,
      email: email,
      userId: userId,
    );
    
    if (result['success'] == true) {
      await _passwordService.clearResetData();
      _resetSessions.remove(sessionId);
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '✅ **Password Updated Successfully!**\n\nYou can now login with your new password.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset_success',
        quickReplies: const [
          '🔐 Login',
          '🎫 Create Ticket',
          '📋 View My Tickets',
          '🔍 Track Ticket',
          '🏠 Main Menu',
        ],
      );
    } else {
      String errorMessage = result['message'] ?? 'Failed to update password';
      
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ $errorMessage',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔄 Try Again',
          '🔑 Generate Another',
          '🏠 Main Menu',
        ],
      );
    }
  }

  /// Handle Resend OTP
  Future<MessageModel> _handleResendOtp(String sessionId) async {
    debugPrint('📱 Handling Resend OTP for session: $sessionId');
    
    final sessionData = _getSessionData(sessionId);
    final email = sessionData?['email'] ?? '';
    final userId = sessionData?['userId'] ?? '';
    
    if (email.isEmpty || userId.isEmpty) {
      return MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Session expired. Please start the password reset process again.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔐 Forgot Password',
          '🏠 Main Menu',
        ],
      );
    }
    
    return await _sendOtpAndRespond(
      email: email,
      userId: userId,
      sessionId: sessionId,
      isResend: true,
    );
  }

  /// Handle Generate Strong Password
  Future<MessageModel> _handleGeneratePassword(String sessionId) async {
    final strongPassword = _generateStrongPassword();
    
    _updateSession(sessionId, {'generatedPassword': strongPassword});
    
    final validation = _passwordService.validatePassword(strongPassword);
    
    return MessageModel(
      id: DateTime.now().toString(),
      text: '🔑 **Generated Strong Password:**\n\n`$strongPassword`\n\n**Password strength:** ${_getStrengthText(validation['strength'])}\n\nPlease use this password or enter your own:',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'password_reset',
      inputType: 'new_password',
      tempData: {
        'step': 'enter_new_password',
        'sessionId': sessionId,
        'generatedPassword': strongPassword
      },
      quickReplies: const [
        '🔑 Use Generated Password',
        '🔄 Generate Another',
        '✏️ Type Password',
        '❌ Cancel',
      ],
    );
  }

  /// Handle Use Generated Password
  Future<MessageModel> _handleUseGeneratedPassword(String sessionId) async {
    final sessionData = _getSessionData(sessionId);
    final generatedPassword = sessionData?['generatedPassword'] ?? '';
    final userId = sessionData?['userId'] ?? '';
    final email = sessionData?['email'] ?? '';
    
    if (generatedPassword.isNotEmpty) {
      final validation = _passwordService.validatePassword(generatedPassword);
      
      if (!validation['isValid']) {
        return MessageModel(
          id: DateTime.now().toString(),
          text: '❌ Generated password doesn\'t meet requirements. Please generate another.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'password_reset',
          inputType: 'new_password',
          tempData: {'step': 'enter_new_password', 'sessionId': sessionId},
          quickReplies: const [
            '🔑 Generate Another',
            '✏️ Type Password',
            '❌ Cancel',
          ],
        );
      }
      
      return await _updatePasswordAndRespond(
        password: generatedPassword,
        userId: userId,
        email: email,
        sessionId: sessionId,
      );
    }
    
    return MessageModel(
      id: DateTime.now().toString(),
      text: '❌ No generated password found. Please generate one first:',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'password_reset',
      inputType: 'new_password',
      tempData: {'step': 'enter_new_password', 'sessionId': sessionId},
      quickReplies: const [
        '🔑 Generate Strong Password',
        '❌ Cancel',
      ],
    );
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong';
      case 5: return 'Very Strong';
      default: return 'Unknown';
    }
  }

  /// Get session data
  Map<String, dynamic>? _getSessionData(String? sessionId) {
    if (sessionId != null && _resetSessions.containsKey(sessionId)) {
      return _resetSessions[sessionId];
    }
    return null;
  }

  /// Update session data
  void _updateSession(String? sessionId, Map<String, dynamic> data) {
    if (sessionId != null && _resetSessions.containsKey(sessionId)) {
      _resetSessions[sessionId]!.addAll(data);
      debugPrint('📱 Session updated: $sessionId -> ${_resetSessions[sessionId]}');
    } else {
      debugPrint('📱 Session not found for update: $sessionId');
    }
  }

  String _generateStrongPassword() {
    const length = 12;
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  // ==================== TICKET METHODS USING SUPPORT SERVICE ====================

  /// Create a new ticket using SupportService
  Future<TicketModel> createTicket({
    required String title,
    required String description,
    required String priority,
    List<String>? attachments,
    List<File>? imageFiles,
  }) async {
    debugPrint('📱 Creating ticket via SupportService: $title');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        throw Exception('User ID not found. Please login again.');
      }
      
      final result = await SupportService.createTicket(
        queryType: title,
        description: description,
        priority: priority.toUpperCase(),
        userId: userId,
        images: imageFiles,
      );
      
      debugPrint('✅ Ticket created successfully via API: $result');
      
      final ticketData = result['data'] ?? {};
      
      String ticketId = 'N/A';
      if (ticketData['data'] != null && ticketData['data']['ticketId'] != null) {
        ticketId = ticketData['data']['ticketId'].toString();
      } else if (ticketData['ticketId'] != null) {
        ticketId = ticketData['ticketId'].toString();
      }
      
      return TicketModel(
        id: ticketId,
        title: title,
        description: description,
        createdAt: DateTime.now(),
        createdBy: userId,
        status: TicketStatus.open,
        priority: _parsePriority(priority),
        attachmentUrls: attachments,
        currentResolutionSummary: null,
        resolvedAt: null,
        closedDate: null,
        userFileName: imageFiles != null && imageFiles.isNotEmpty ? 'uploaded' : null,
        developerFileName: null,
        messages: [
          TicketMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            text: description,
            senderId: userId,
            senderName: 'You',
            timestamp: DateTime.now(),
            isFromUser: true,
          ),
        ],
      );
    } catch (e) {
      debugPrint('❌ Error creating ticket via API: $e');
      rethrow;
    }
  }

  /// Get user tickets
  Future<List<TicketModel>> getUserTickets() async {
    debugPrint('📱 Fetching user tickets from API');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final token = prefs.getString('auth_token') ?? '';
      
      if (userId.isEmpty || token.isEmpty) {
        debugPrint('⚠️ User ID or token not found');
        return [];
      }
      
      debugPrint('📋 Calling SupportService.getTodayTickets() for user: $userId');
      
      final result = await SupportService.getTodayTickets(status: 'OPEN');
      
      debugPrint('📊 API Response received: $result');
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        List<TicketModel> tickets = [];
        
        if (data['data'] != null && data['data'] is List) {
          debugPrint('📋 Found tickets in data["data"] as List');
          final List<dynamic> ticketsData = data['data'];
          tickets = ticketsData.map((json) => _parseTicketFromJson(json)).toList();
        } else if (data is List) {
          debugPrint('📋 Data is a direct List');
          tickets = data.map((json) => _parseTicketFromJson(json)).toList();
        }
        
        debugPrint('✅ Successfully parsed ${tickets.length} tickets');
        return tickets;
      } else {
        debugPrint('⚠️ API returned success=false or no data: ${result['message']}');
        return [];
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching tickets from API: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Helper method to parse ticket from JSON
  TicketModel _parseTicketFromJson(Map<String, dynamic> json) {
    debugPrint('🔍 Parsing ticket JSON: ${json['ticketId']} - ${json['title']}');
    
    TicketStatus status = TicketStatus.open;
    if (json['status'] != null) {
      switch (json['status'].toString().toUpperCase()) {
        case 'OPEN': status = TicketStatus.open; break;
        case 'IN_PROGRESS':
        case 'INPROGRESS': status = TicketStatus.inProgress; break;
        case 'RESOLVED': status = TicketStatus.resolved; break;
        case 'CLOSED': status = TicketStatus.closed; break;
        case 'REOPENED': status = TicketStatus.reopened; break;
        case 'ON_HOLD':
        case 'ONHOLD': status = TicketStatus.onHold; break;
      }
    }
    
    TicketPriority priority = TicketPriority.medium;
    if (json['priority'] != null) {
      switch (json['priority'].toString().toUpperCase()) {
        case 'LOW': priority = TicketPriority.low; break;
        case 'MEDIUM': priority = TicketPriority.medium; break;
        case 'HIGH': priority = TicketPriority.high; break;
        case 'CRITICAL': priority = TicketPriority.critical; break;
      }
    }
    
    DateTime createdAt = DateTime.now();
    if (json['createdDate'] != null) {
      try {
        createdAt = DateTime.parse(json['createdDate']);
      } catch (e) {
        debugPrint('⚠️ Error parsing createdDate: ${json['createdDate']}');
      }
    }
    
    DateTime? resolvedAt;
    if (json['resolvedDate'] != null) {
      try {
        resolvedAt = DateTime.parse(json['resolvedDate']);
      } catch (e) {
        debugPrint('⚠️ Error parsing resolvedDate: ${json['resolvedDate']}');
      }
    }
    
    DateTime? closedDate;
    if (json['closedDate'] != null) {
      try {
        closedDate = DateTime.parse(json['closedDate']);
      } catch (e) {
        debugPrint('⚠️ Error parsing closedDate: ${json['closedDate']}');
      }
    }
    
    return TicketModel(
      id: json['ticketId']?.toString() ?? json['id']?.toString() ?? 'N/A',
      title: json['title'] ?? 'No title',
      description: json['description'] ?? '',
      createdAt: createdAt,
      createdBy: json['userid'] ?? json['createdBy'] ?? 'Unknown',
      status: status,
      priority: priority,
      assignedTo: json['assignedTo'],
      currentResolutionSummary: json['currentResolutionSummary'],
      resolvedAt: resolvedAt,
      closedDate: closedDate,
      userFileName: json['userFileName'],
      developerFileName: json['developerFileName'],
      messages: [],
    );
  }

  /// Get ticket details by ID
  Future<TicketModel> getTicketDetails(String ticketId) async {
    debugPrint('📱 Fetching ticket details for ID: $ticketId');
    
    try {
      final tickets = await getUserTickets();
      final ticket = tickets.firstWhere(
        (t) => t.id == ticketId,
        orElse: () => throw Exception('Ticket not found'),
      );
      
      return ticket;
    } catch (e) {
      debugPrint('❌ Error fetching ticket details: $e');
      rethrow;
    }
  }

  /// Add message to ticket
  Future<TicketModel> addTicketMessage(String ticketId, String message) async {
    debugPrint('📱 Adding message to ticket: $ticketId');
    
    try {
      final ticket = await getTicketDetails(ticketId);
      return ticket.copyWith(
        messages: [
          ...ticket.messages ?? [],
          TicketMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            text: message,
            senderId: ticket.createdBy,
            senderName: 'You',
            timestamp: DateTime.now(),
            isFromUser: true,
          ),
        ],
      );
    } catch (e) {
      debugPrint('❌ Error adding message: $e');
      rethrow;
    }
  }

  /// Parse priority string to enum
  TicketPriority _parsePriority(String priority) {
    switch (priority.toUpperCase()) {
      case 'LOW': return TicketPriority.low;
      case 'MEDIUM': return TicketPriority.medium;
      case 'HIGH': return TicketPriority.high;
      case 'CRITICAL': return TicketPriority.critical;
      default: return TicketPriority.medium;
    }
  }
}