import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/ai/ticket_model.dart';
import 'package:staff_mate/services/chat_services.dart';
import 'package:staff_mate/services/support_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'message_model.dart';
import 'dart:async';
import 'package:staff_mate/services/forgetpassword_service.dart';

// Enum for view states
enum ViewState { idle, busy, loading }

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ForgetPasswordService _passwordService = ForgetPasswordService();
    final _navigationController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationController.stream;
  final _focusKeyboardController = StreamController<String>.broadcast();
  Stream<String> get focusKeyboardStream => _focusKeyboardController.stream;
  
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isBotTyping = false;
  String? _error;
  String? _currentInputType;
  String? _currentSessionId;
  Map<String, dynamic> _sessionData = {};
  bool _isApiCallInProgress = false;
  String? _currentApiOperation;
  ViewState _state = ViewState.idle;
  
  // Password reset specific variables
  bool _otpSent = false;
  bool _otpVerified = false;
  int _remainingTime = 300;
  Timer? _timer;
  String? _otpError;
  bool _showResendOption = false;
  String? _currentUserId;
  String? _currentEmail;
  
  // Flag to prevent duplicate processing
  bool _isProcessingQuickReply = false;
  
  // Sorting and Filtering fields
  Map<String, dynamic>? _currentTicketFilter;
  String? _currentSortBy;
  bool? _sortAscending;
  
  // Query type options for dropdown
  static const List<String> queryTypeOptions = [
    "Access Request",
    "Billing Issue",
    "Data Correction Issue",
    "Feature Request",
    "General Query",
    "Network Issue",
    "Password Request",
    "Software Issue",
    "Other",
  ];
  
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isBotTyping => _isBotTyping;
  String? get error => _error;
  String? get currentInputType => _currentInputType;
  String? get currentSessionId => _currentSessionId;
  Map<String, dynamic> get sessionData => _sessionData;
  bool get isApiCallInProgress => _isApiCallInProgress;
  String? get currentApiOperation => _currentApiOperation;
  bool get otpSent => _otpSent;
  bool get otpVerified => _otpVerified;
  ViewState get state => _state;
  
  // Sorting and Filtering getters
  Map<String, dynamic>? get currentTicketFilter => _currentTicketFilter;
  String? get currentSortBy => _currentSortBy;
  bool? get sortAscending => _sortAscending;
  List<String> get queryTypeOptionsList => queryTypeOptions;

  ChatProvider() {
    initializeChat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _navigationController.close();
    _focusKeyboardController.close();
    super.dispose();
  }

  void setState(ViewState newState) {
    _state = newState;
    notifyListeners();
  }

  // Sorting and Filtering methods
  void setTicketFilter(Map<String, dynamic> filter) {
    _currentTicketFilter = filter;
    notifyListeners();
  }

  void clearFilter(String filterKey) {
    if (_currentTicketFilter != null) {
      _currentTicketFilter!.remove(filterKey);
      if (_currentTicketFilter!.isEmpty) {
        _currentTicketFilter = null;
      }
      notifyListeners();
    }
  }

  void clearAllFilters() {
    _currentTicketFilter = null;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _currentSortBy = sortBy;
    notifyListeners();
  }

  void setSortAscending(bool ascending) {
    _sortAscending = ascending;
    notifyListeners();
  }

  Future<void> initializeChat() async {
    await loadChatHistory();
  }

// Add this method to ChatProvider
Future<void> _loadCurrentEmailFromPrefs() async {
  if (_currentEmail == null || _currentEmail!.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    _currentEmail = prefs.getString('userEmail') ?? prefs.getString('email') ?? '';
  }
}

  Future<void> loadChatHistory() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final history = await _chatService.getChatHistory();
      
      _messages = history;
      _isLoading = false;
      _currentInputType = null;
      _currentSessionId = null;
      _sessionData = {};
      _otpSent = false;
      _otpVerified = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load chat: $e';
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
        notifyListeners();
      } else {
        _showResendOption = true;
        _timer?.cancel();
        notifyListeners();
      }
    });
  }

  // Method for processing option clicks
Future<void> processOption(String option) async {
  // Prevent duplicate processing
  if (_isProcessingQuickReply) {
    debugPrint('⚠️ Already processing a quick reply, ignoring: $option');
    return;
  }

  try {
    _isProcessingQuickReply = true;

    // Add user message
    final userMessage = MessageModel(
      id: DateTime.now().toString(),
      text: option,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    notifyListeners();

    // Show typing indicator
    _isBotTyping = true;
    notifyListeners();

    // ─── PHONE CALL ───────────────────────────────────────────────────────────
    if (option.startsWith('📞 Call ')) {
      final number = option.replaceFirst('📞 Call ', '').replaceAll(' ', '');
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── TICKET IMAGE VIEWING ─────────────────────────────────────────────────
    if (option.startsWith('🖼️ View User Image for #')) {
      final ticketId = int.tryParse(
          option.replaceAll('🖼️ View User Image for #', '').trim());
      if (ticketId != null) {
        await viewTicketImage(ticketId, 'user');
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    if (option.startsWith('🖼️ View Developer Image for #')) {
      final ticketId = int.tryParse(
          option.replaceAll('🖼️ View Developer Image for #', '').trim());
      if (ticketId != null) {
        await viewTicketImage(ticketId, 'developer');
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    if (option.startsWith('📋 Back to Ticket #')) {
      final ticketId = int.tryParse(
          option.replaceAll('📋 Back to Ticket #', '').trim());
      if (ticketId != null) {
        await fetchTicketDetails(ticketId);
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── TRACK TICKET BY STATUS ───────────────────────────────────────────────
    if ((option.startsWith('🔍 ') && option.contains('Tickets')) ||
        (option.contains('OPEN Tickets') && option.startsWith('🔍')) ||
        (option.contains('IN_PROGRESS Tickets') && option.startsWith('🔍')) ||
        (option.contains('RESOLVED Tickets') && option.startsWith('🔍')) ||
        (option.contains('CLOSED Tickets') && option.startsWith('🔍'))) {
      debugPrint('🎯 Track status selected: $option');

      String status = option
          .replaceAll('🔍 ', '')
          .replaceAll(' Tickets', '')
          .trim();

      debugPrint('📋 Extracted track status: "$status"');

      if (['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].contains(status)) {
        await fetchTicketsForTracking(status);
      } else {
        debugPrint('⚠️ Invalid status: $status');
        _showError('Invalid status selected');
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── TRACK SPECIFIC TICKET ────────────────────────────────────────────────
    if (option.startsWith('🔍 Track #')) {
      final ticketId = option.replaceAll('🔍 Track #', '').trim();
      final id = int.tryParse(ticketId);
      if (id != null) {
        await fetchTicketDetails(id);
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── VIEW MY TICKETS (must come before status selection) ──────────────────
    if (option == '📋 View My Tickets' ||
        option == 'View My Tickets' ||
        option.toLowerCase().contains('view my tickets') ||
        option.toLowerCase().contains('view tickets') ||
        option.toLowerCase().contains('my tickets')) {
      debugPrint('🔍 DEBUG: View My Tickets detected - showing status options');
      await showTicketStatusOptions();
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── VIEW TICKETS BY STATUS ───────────────────────────────────────────────
    if ((option.startsWith('📋 ') && option.contains('Tickets')) ||
        option.contains('OPEN Tickets') ||
        option.contains('IN_PROGRESS Tickets') ||
        option.contains('RESOLVED Tickets') ||
        option.contains('CLOSED Tickets')) {
      debugPrint('🎯 Status selected: $option');

      String status = option
          .replaceAll('📋 ', '')
          .replaceAll(' Tickets', '')
          .trim();

      debugPrint('📋 Extracted status: "$status"');

      if (['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].contains(status)) {
        await fetchTicketsByStatus(status);
      } else {
        debugPrint('⚠️ Invalid status: $status');
        _showError('Invalid status selected');
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── BACK TO LIST ─────────────────────────────────────────────────────────
    if (option == '📋 Back to List' || option == 'Back to List') {
      await showTicketStatusOptions();
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── MAIN MENU ────────────────────────────────────────────────────────────
    if (option == '🏠 Main Menu' || option == 'Main Menu') {
      clearSession();
      final botResponse = await _chatService.processOption('Main Menu');
      if (botResponse != null) {
        _messages.add(botResponse);
        notifyListeners();
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── TRY AGAIN ────────────────────────────────────────────────────────────
    if (option == '🔄 Try Again' || option == 'Try Again') {
      if (_otpSent && !_otpVerified) {
        _currentInputType = 'otp';
      } else {
        final botResponse = await _chatService.processOption('Main Menu');
        if (botResponse != null) {
          _messages.add(botResponse);
          notifyListeners();
        }
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── RESEND OTP ───────────────────────────────────────────────────────────
    if (option == '🔄 Resend OTP' || option == 'Resend OTP') {
      await handleResendOtp();
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── CANCEL ───────────────────────────────────────────────────────────────
    if (option == '❌ Cancel' || option == 'Cancel') {
      clearSession();
      final botResponse = await _chatService.processOption('Main Menu');
      if (botResponse != null) {
        _messages.add(botResponse);
        notifyListeners();
      }
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      return;
    }

    // ─── TEXT INPUT DURING ACTIVE FLOW ───────────────────────────────────────
    // (covers OTP entry and new password entry)
    if (_currentInputType != null) {
      _isBotTyping = false;
      _isProcessingQuickReply = false;
      await processTextInput(option);
      return;
    }

    // ─── ALL OTHER OPTIONS → CHAT SERVICE ────────────────────────────────────
    final botResponse = await _chatService.processOption(
      option,
      sessionId: _currentSessionId,
    );

    _isBotTyping = false;

    if (botResponse != null) {
      // If the service returns a password_reset step, update session state
      // and show the new-password prompt with validation hints directly
      if (botResponse.type == 'password_reset' && botResponse.inputType != null) {
        _currentInputType = botResponse.inputType;
        _currentSessionId = botResponse.tempData?['sessionId'];
        _sessionData = botResponse.tempData ?? {};

        if (botResponse.tempData != null) {
          _currentUserId = botResponse.tempData!['userId'];
          _currentEmail = botResponse.tempData!['email'];
        }
        await _loadCurrentEmailFromPrefs();

        // If we just moved into the "enter new password" step, replace the
        // bot message with one that shows validation rules and no Generate/Type
        // options — just focus the text keyboard and let the user type.
        if (_currentInputType == 'new_password_input') {
          final passwordPrompt = MessageModel(
            id: DateTime.now().toString(),
            text: '🔐 OTP verified! Please type your new password:\n\n'
                '• Min 8 characters\n'
                '• A–Z  (uppercase)\n'
                '• a–z  (lowercase)\n'
                '• 0–9  (number)\n'
                '• Special char  e.g. !@#\$%^&*',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'password_reset',
            inputType: 'new_password_input',
            tempData: botResponse.tempData,
            quickReplies: const ['❌ Cancel', '🏠 Main Menu'],
          );
          _messages.add(passwordPrompt);
          notifyListeners();

          // Signal the UI to open the alpha keyboard (not number pad)
          _focusKeyboardController.add('focus_text');
          return;
        }
      }

      // Redirect to ticket creation screen
      if (botResponse.type == 'redirect' &&
          botResponse.formField == 'ticket_creation') {
        _messages.add(botResponse);
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigationController.add('create_ticket');
        });
      } else {
        _messages.add(botResponse);
        notifyListeners();
      }
    }
  } catch (e) {
    _isBotTyping = false;
    _messages.add(MessageModel(
      id: DateTime.now().toString(),
      text: 'Sorry, an error occurred. Please try again.',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'error',
      quickReplies: const ['🏠 Main Menu'],
    ));
    notifyListeners();
  } finally {
    _isProcessingQuickReply = false;
  }
}

  // Show ticket status options for View Tickets
  Future<void> showTicketStatusOptions() async {
    debugPrint('📋 Showing ticket status options');
    
    final statusOptions = MessageModel(
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
    
    _messages.add(statusOptions);
    notifyListeners();
  }

  // Show track ticket status options
  Future<void> showTrackTicketStatusOptions() async {
    debugPrint('🔍 Showing track ticket status options');
    
    final statusOptions = MessageModel(
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
    
    _messages.add(statusOptions);
    notifyListeners();
  }

  // Fetch tickets by status for View Tickets
  Future<void> fetchTicketsByStatus(String status) async {
    debugPrint('📋 Fetching tickets with status: $status');
    
    try {
      setState(ViewState.busy);
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        _showError('User ID not found. Please login again.');
        setState(ViewState.idle);
        return;
      }
      
      debugPrint('👤 User ID: $userId');
      
      // Get today's date
      final today = DateTime.now().toIso8601String().split('T')[0];
      debugPrint('📅 Date: $today');
      
      // Call API with status
      final result = await SupportService.getTicketsByUserAndDate(
        userId: userId,
        date: today,
        status: status,
      );
      
      debugPrint('📊 API Response received');
      
      List<TicketModel> tickets = [];
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('📦 Data type: ${data.runtimeType}');
        
        // Extract tickets from response
        if (data['data'] != null && data['data'] is List) {
          debugPrint('📋 Found tickets in data["data"] as List');
          final List<dynamic> ticketsData = data['data'];
          
          tickets = ticketsData
              .map((json) {
                try {
                  return TicketModel.fromJson(json);
                } catch (e) {
                  debugPrint('⚠️ Error parsing ticket: $e');
                  return null;
                }
              })
              .whereType<TicketModel>()
              .where((t) => t.statusText == status)
              .toList();
              
        } else if (data is List) {
          debugPrint('📋 Data is a direct List');
          tickets = data
              .map((json) {
                try {
                  return TicketModel.fromJson(json);
                } catch (e) {
                  debugPrint('⚠️ Error parsing ticket: $e');
                  return null;
                }
              })
              .whereType<TicketModel>()
              .where((t) => t.statusText == status)
              .toList();
        }
        
        // Limit to 10 tickets
        if (tickets.length > 10) {
          tickets = tickets.sublist(0, 10);
        }
        
        debugPrint('✅ Found ${tickets.length} tickets with status $status');
      } else {
        debugPrint('⚠️ API returned no data: ${result['message']}');
      }
      
      if (tickets.isEmpty) {
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '📋 No **$status** tickets found.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'info',
          quickReplies: const [
            '📋 View My Tickets',
            '🏠 Main Menu',
          ],
        ));
      } else {
        _messages.add(MessageModel(
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
        ));
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error fetching tickets by status: $e');
      _showError('Failed to fetch tickets: $e');
    } finally {
      setState(ViewState.idle);
    }
  }

  // NEW METHOD: Fetch tickets for tracking
  Future<void> fetchTicketsForTracking(String status) async {
    debugPrint('📋 Fetching tickets for tracking with status: $status');
    
    try {
      setState(ViewState.busy);
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        _showError('User ID not found. Please login again.');
        setState(ViewState.idle);
        return;
      }
      
      // Get today's date
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Call API with status
      final result = await SupportService.getTicketsByUserAndDate(
        userId: userId,
        date: today,
        status: status,
      );
      
      List<TicketModel> tickets = [];
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        
        // Extract tickets from response
        if (data['data'] != null && data['data'] is List) {
          final List<dynamic> ticketsData = data['data'];
          
          tickets = ticketsData
              .map((json) {
                try {
                  return TicketModel.fromJson(json);
                } catch (e) {
                  return null;
                }
              })
              .whereType<TicketModel>()
              .where((t) => t.statusText == status)
              .toList();
              
        } else if (data is List) {
          tickets = data
              .map((json) {
                try {
                  return TicketModel.fromJson(json);
                } catch (e) {
                  return null;
                }
              })
              .whereType<TicketModel>()
              .where((t) => t.statusText == status)
              .toList();
        }
      }
      
      if (tickets.isEmpty) {
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '📋 No **$status** tickets found to track.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'info',
          quickReplies: const [
            '🔍 Track Ticket',
            '🏠 Main Menu',
          ],
        ));
      } else {
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '🔍 **Select a ticket to track**\n\nChoose a ticket to view its progress:',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'track_ticket_list',
          tickets: tickets,
          quickReplies: const [
            '🏠 Main Menu',
          ],
        ));
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error fetching tickets for tracking: $e');
      _showError('Failed to fetch tickets: $e');
    } finally {
      setState(ViewState.idle);
    }
  }

  // Method for processing text input
  Future<void> processTextInput(String text) async {
    debugPrint('📱 processTextInput called with text: "$text", inputType: $_currentInputType, sessionId: $_currentSessionId');
    
    if (_currentInputType == null) {
      await processOption(text);
      return;
    }

    try {
      // Add user's text input to chat
      final userMessage = MessageModel(
        id: DateTime.now().toString(),
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        type: 'user_input',
      );
      
      _messages.add(userMessage);
      notifyListeners();

      // Show typing indicator
      _isBotTyping = true;
      notifyListeners();

      // Process based on input type
      if (_currentInputType == 'otp') {
        debugPrint('📱 Processing OTP input: $text');
        
        if (text.trim().isEmpty) {
          _otpError = "Please enter the OTP";
          _showError(_otpError!);
          _isBotTyping = false;
          return;
        }

        // Use the service's validation method
        if (!_chatService.isValidOTP(text.trim())) {
          _otpError = "OTP must be 6 digits";
          _showError(_otpError!);
          _isBotTyping = false;
          return;
        }

        if (_currentUserId == null || _currentEmail == null) {
          _showError("Session expired. Please start over.");
          _isBotTyping = false;
          return;
        }

        // Show loading state
        _isApiCallInProgress = true;
        _currentApiOperation = 'Verifying OTP...';
        notifyListeners();

        // Call verifyOTP API
        final result = await _passwordService.verifyOTP(
          userOtp: text.trim(),
          userId: _currentUserId!,
        );

        _isApiCallInProgress = false;
        _currentApiOperation = null;

        if (result['success'] == true) {
          // Save reset data with OTP
          await _passwordService.saveResetData(
            email: _currentEmail!,
            userId: _currentUserId!,
            otp: text.trim(),
          );
          
          _otpVerified = true;
          _currentInputType = 'new_password';
          
          final response = MessageModel(
            id: DateTime.now().toString(),
            text: '✅ OTP Verified Successfully!\n\nEnter your new password:',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'password_reset',
            inputType: 'new_password',
            tempData: {
              'step': 'enter_new_password',
              'userId': _currentUserId,
              'email': _currentEmail,
              'sessionId': _currentSessionId
            },
            quickReplies: const [
              '🔑 Generate Strong Password',
              '✏️ Type Password',
              '❌ Cancel',
              '🏠 Main Menu',
            ],
          );
          _messages.add(response);
        } else {
          _otpError = result['message'] ?? "Invalid or expired OTP";
          _showError(_otpError!);
        }
      }
      
      // Handle New Password input
      else if (_currentInputType == 'new_password' || _currentInputType == 'new_password_input') {
        debugPrint('📱 Processing Password input: $text');
        
        if (text.trim().isEmpty) {
          _showError("Please enter a new password");
          _isBotTyping = false;
          return;
        }

        final passwordValidation = _passwordService.validatePassword(text.trim());
        if (!passwordValidation['isValid']) {
          _showError(passwordValidation['errors'].first.toString());
          _isBotTyping = false;
          return;
        }

        if (_currentEmail == null || _currentUserId == null) {
          _showError("Session expired. Please start the process again.");
          _isBotTyping = false;
          return;
        }

        // Show loading state
        _isApiCallInProgress = true;
        _currentApiOperation = 'Updating password...';
        notifyListeners();

        // Call updatePassword API
        final result = await _passwordService.updatePassword(
          password: text.trim(),
          email: _currentEmail!,
          userId: _currentUserId!,
        );

        _isApiCallInProgress = false;
        _currentApiOperation = null;

        if (result['success'] == true) {
          await _passwordService.clearResetData();
          _currentInputType = null;
          _otpSent = false;
          _otpVerified = false;
          _currentUserId = null;
          _currentEmail = null;
          _currentSessionId = null;
          _sessionData.clear();
          
          final response = MessageModel(
            id: DateTime.now().toString(),
            text: '✅ Password Updated Successfully!\n\nYou can now login with your new password.',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'password_reset_success',
            quickReplies: const [
              '🔐 Login',
              '🎫 Create Ticket',
              '🏠 Main Menu',
            ],
          );
          _messages.add(response);
          notifyListeners();
        } else {
          _showError(result['message'] ?? "Failed to update password. Please try again.");
        }
      }

      _isBotTyping = false;
      notifyListeners();

    } catch (e) {
      _isBotTyping = false;
      _isApiCallInProgress = false;
      debugPrint('❌ Error in processTextInput: $e');
      
      _showError('An error occurred. Please try again.');
    }
  }

  // Handle Resend OTP
  Future<void> handleResendOtp() async {
    if (_currentEmail == null || _currentUserId == null) {
      _showError("Session expired. Please start again.");
      return;
    }

    _showResendOption = false;
    _remainingTime = 300;
    _otpError = null;
    _startTimer();

    // Show loading
    _isApiCallInProgress = true;
    _currentApiOperation = 'Resending OTP...';
    notifyListeners();

    // Call sendEmailOTP API again
    final result = await _passwordService.sendEmailOTP(
      email: _currentEmail!,
      userId: _currentUserId!,
    );

    _isApiCallInProgress = false;
    _currentApiOperation = null;

    if (result['success'] == true) {
      final response = MessageModel(
        id: DateTime.now().toString(),
        text: '✅ OTP has been resent to $_currentEmail\n\nPlease enter the 6-digit OTP:',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset',
        inputType: 'otp',
        tempData: {
          'step': 'enter_otp',
          'userId': _currentUserId,
          'email': _currentEmail,
          'sessionId': _currentSessionId
        },
        quickReplies: const [
          '🔄 Resend OTP',
          '❌ Cancel',
          '🏠 Main Menu',
        ],
      );
      _messages.add(response);
      notifyListeners();
    } else {
      _showError(result['message'] ?? "Failed to resend OTP");
    }
  }

  // Handle Generate Strong Password
  Future<void> handleGeneratePassword() async {
    final strongPassword = _chatService.generateStrongPassword();
    final validation = _passwordService.validatePassword(strongPassword);
    
    // Store the generated password in session data
    _sessionData['generatedPassword'] = strongPassword;
    
    final response = MessageModel(
      id: DateTime.now().toString(),
      text: '🔑 Generated Strong Password:\n\n`$strongPassword`\n\nPassword strength: ${_getStrengthText(validation['strength'])}\n\nPlease use this password or enter your own:',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'password_reset',
      inputType: 'new_password',
      tempData: {
        'step': 'enter_new_password',
        'userId': _currentUserId,
        'email': _currentEmail,
        'sessionId': _currentSessionId,
        'generatedPassword': strongPassword
      },
      quickReplies: const [
        '🔑 Use Generated Password',
        '🔄 Generate Another',
        '✏️ Type Password',
        '❌ Cancel',
      ],
    );
    
    _messages.add(response);
    notifyListeners();
  }

  // Handle Use Generated Password
  Future<void> handleUseGeneratedPassword(String password) async {
    debugPrint('📱 Using generated password: $password');
    
    if (_currentEmail == null || _currentUserId == null) {
      _showError("Session expired");
      return;
    }

    // Validate the generated password
    final validation = _passwordService.validatePassword(password);
    if (!validation['isValid']) {
      _showError("Generated password doesn't meet requirements. Please generate another.");
      return;
    }

    _isApiCallInProgress = true;
    _currentApiOperation = 'Updating password...';
    notifyListeners();

    final result = await _passwordService.updatePassword(
      password: password,
      email: _currentEmail!,
      userId: _currentUserId!,
    );

    _isApiCallInProgress = false;
    _currentApiOperation = null;

    if (result['success'] == true) {
      await _passwordService.clearResetData();
      _currentInputType = null;
      _otpSent = false;
      _otpVerified = false;
      _currentUserId = null;
      _currentEmail = null;
      _currentSessionId = null;
      _sessionData.clear();
      
      final response = MessageModel(
        id: DateTime.now().toString(),
        text: '✅ Password Updated Successfully!\n\nYou can now login with your new password.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'password_reset_success',
        quickReplies: const [
          '🔐 Login',
          '🎫 Create Ticket',
          '🏠 Main Menu',
        ],
      );
      _messages.add(response);
      notifyListeners();
    } else {
      _showError(result['message'] ?? "Failed to update password");
    }
  }

  // UPDATED: Fetch user tickets - now shows status options instead
  Future<void> fetchUserTickets() async {
    await showTicketStatusOptions();
  }

  // UPDATED: Fetch ticket details by ID - shows queryType/title properly
  Future<void> fetchTicketDetails(int ticketId) async {
    try {
      setState(ViewState.busy);
      
      final result = await SupportService.getTodayTickets(status: 'OPEN');
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        List<dynamic> ticketsData = [];
        
        // Extract tickets from response
        if (data['data'] != null && data['data'] is List) {
          ticketsData = data['data'];
        } else if (data is List) {
          ticketsData = data;
        }
        
        // Find the specific ticket
        final ticketJson = ticketsData.firstWhere(
          (t) => t['ticketId'] == ticketId || t['id'] == ticketId,
          orElse: () => null,
        );
        
        if (ticketJson != null) {
          final ticket = TicketModel.fromJson(ticketJson);
          
          // Get the queryType/title - try both fields
          String ticketTitle = ticket.queryType ?? ticket.title ?? 'No Title';
          
          // Create quick replies based on available images
          List<String> quickReplies = [];
          if (ticket.hasUserImage) {
            quickReplies.add('🖼️ View User Image for #${ticket.id}');
          }
          if (ticket.hasResUserImage) {
            quickReplies.add('🖼️ View Developer Image for #${ticket.id}');
          }
          quickReplies.addAll(['📋 Back to List', '🏠 Main Menu']);
          
          final detailMessage = MessageModel(
            id: DateTime.now().toString(),
            text: '📋 **Ticket #${ticket.id} Details**\n\n'
                   '**Query Type:** $ticketTitle\n'
                   '**Description:** ${ticket.description}\n'
                   '**Status:** ${ticket.statusText}\n'
                   '**Priority:** ${ticket.priorityText}\n'
                   '**Created:** ${_formatDate(ticket.createdAt)}\n'
                   '**Images:** ${ticket.hasUserImage ? '✓ User' : '✗ User'}, ${ticket.hasResUserImage ? '✓ Developer' : '✗ Developer'}',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'track_ticket_detail',
            ticket: ticket,
            quickReplies: quickReplies,
          );
          
          _messages.add(detailMessage);
        } else {
          // Ticket not found
          _messages.add(MessageModel(
            id: DateTime.now().toString(),
            text: '❌ Ticket #$ticketId not found.',
            isUser: false,
            timestamp: DateTime.now(),
            type: 'error',
            quickReplies: const ['📋 View My Tickets', '🏠 Main Menu'],
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching ticket details: $e');
      _messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Error fetching ticket details: ${e.toString()}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const ['📋 View My Tickets', '🏠 Main Menu'],
      ));
    } finally {
      setState(ViewState.idle);
    }
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // UPDATED: View ticket image method with proper base64 handling - KEPT YOUR ORIGINAL CODE
  Future<void> viewTicketImage(int ticketId, String fileType) async {
    try {
      setState(ViewState.busy);

      final loadingMsg = MessageModel(
        id: DateTime.now().toString(),
        text: '🖼️ Loading image for ticket #$ticketId...',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'loading',
      );
      _messages.add(loadingMsg);
      notifyListeners();

      debugPrint('📸 ===== VIEW IMAGE =====');
      debugPrint('Ticket ID: $ticketId, Type: $fileType');

      final result = await SupportService.viewTicketImageBase64(
        ticketId: ticketId,
        fileType: fileType.toUpperCase(),
      );

      // Remove loading message
      _messages.removeLast();

      if (result['success'] != true || result['data'] == null) {
        final errorMsg = result['message'] ?? 'Failed to load image';
        debugPrint('❌ API returned error: $errorMsg');
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '❌ Failed to load image: $errorMsg',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'error',
          quickReplies: ['📋 Back to Ticket #$ticketId', '📋 View My Tickets', '🏠 Main Menu'],
        ));
        notifyListeners();
        return;
      }

      final data = result['data'];
      debugPrint('📦 Data keys: ${data.keys.toList()}');

      final rawBase64 = data['imageBase64'];
      if (rawBase64 == null || rawBase64.toString().isEmpty) {
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '📷 No ${fileType.toUpperCase()} image found for ticket #$ticketId.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'info',
          quickReplies: ['📋 Back to Ticket #$ticketId', '📋 View My Tickets', '🏠 Main Menu'],
        ));
        notifyListeners();
        return;
      }

      // Service already stripped the prefix — decode directly
      final Uint8List imageBytes;
      try {
        imageBytes = base64Decode(rawBase64.toString());
      } catch (e) {
        debugPrint('❌ base64Decode failed: $e');
        _messages.add(MessageModel(
          id: DateTime.now().toString(),
          text: '❌ Image data is corrupted. Please contact support.',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'error',
          quickReplies: ['📋 Back to Ticket #$ticketId', '📋 View My Tickets', '🏠 Main Menu'],
        ));
        notifyListeners();
        return;
      }

      final fileName = data['fileName'] ??
          (fileType.toLowerCase() == 'user' ? 'user_image.png' : 'developer_image.png');

      debugPrint('✅ Decoded ${imageBytes.length} bytes — $fileName');

      _messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: '🖼️ **Ticket #$ticketId** — ${fileType.toUpperCase()} Image\nFile: $fileName',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_image',
        imageData: imageBytes,
        quickReplies: ['📋 Back to Ticket #$ticketId', '📋 View My Tickets', '🏠 Main Menu'],
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Unexpected error in viewTicketImage: $e');

      if (_messages.isNotEmpty && _messages.last.type == 'loading') {
        _messages.removeLast();
      }

      _messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Error loading image: ${e.toString().replaceAll('Exception:', '').trim()}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: ['📋 Back to Ticket #$ticketId', '📋 View My Tickets', '🏠 Main Menu'],
      ));
      notifyListeners();
    } finally {
      setState(ViewState.idle);
    }
  }

  // UPDATED: Create a new ticket with queryType dropdown support
  Future<void> createTicket({
    required String queryType, // Changed from title to queryType
    required String description,
    required String priority,
    List<String>? attachments,
    List<File>? imageFiles, // KEPT YOUR ATTACHMENT PARAMETER
  }) async {
    try {
      _isLoading = true;
      _isApiCallInProgress = true;
      _currentApiOperation = 'Creating ticket...';
      notifyListeners();

      debugPrint('📝 Creating ticket with:');
      debugPrint('  Query Type: $queryType');
      debugPrint('  Description: $description');
      debugPrint('  Priority: $priority');
      debugPrint('  Images count: ${imageFiles?.length ?? 0}'); // Shows attachments

      // Get user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      // Call SupportService with queryType parameter
      final result = await SupportService.createTicket(
        queryType: queryType, // Use queryType
        description: description,
        priority: priority.toUpperCase(),
        userId: userId,
        images: imageFiles, // KEPT YOUR ATTACHMENTS
      );

      debugPrint('✅ API Response in ChatProvider: $result');

      // Parse the response
      final ticketData = result['data'] ?? {};
      String ticketId = 'N/A';
      
      if (ticketData['ticketId'] != null) {
        ticketId = ticketData['ticketId'].toString();
      } else if (ticketData['data'] != null && ticketData['data']['ticketId'] != null) {
        ticketId = ticketData['data']['ticketId'].toString();
      } else if (ticketData['id'] != null) {
        ticketId = ticketData['id'].toString();
      }

      // Create TicketModel from response
      final ticket = TicketModel(
        id: ticketId,
        title: queryType, // Use queryType as title
        queryType: queryType, // Also set queryType
        description: description,
        createdAt: DateTime.now(),
        createdBy: userId,
        status: TicketStatus.open,
        priority: _parsePriority(priority),
        attachmentUrls: attachments,
        // hasUserImage: imageFiles != null && imageFiles.isNotEmpty,
      );

      // Add success message to chat
      _messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: '✅ **Ticket #$ticketId created successfully!**\n\n'
              '**Query Type:** $queryType\n'
              '**Description:** $description\n'
              '**Priority:** $priority\n'
              '**Images:** ${imageFiles?.length ?? 0} attached\n\n'
              'Our support team will look into this shortly.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_confirmation',
        ticket: ticket,
        quickReplies: const [
          '📋 View My Tickets',
          '🎫 Create Ticket',
          '🏠 Main Menu'
        ],
      ));

      _isLoading = false;
      _isApiCallInProgress = false;
      _currentApiOperation = null;
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      _isApiCallInProgress = false;
      _currentApiOperation = null;
      
      debugPrint('❌ Error creating ticket: $e');
      
      _messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: '❌ **Failed to create ticket**\n\nError: $e\n\nPlease try again.',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const [
          '🔄 Try Again',
          '🎫 Create Ticket',
          '🏠 Main Menu'
        ],
      ));
      
      notifyListeners();
    }
  }

  // Helper method to parse priority
  TicketPriority _parsePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'low': return TicketPriority.low;
      case 'medium': return TicketPriority.medium;
      case 'high': return TicketPriority.high;
      case 'critical': return TicketPriority.critical;
      default: return TicketPriority.medium;
    }
  }

  // Helper method to show error messages
  void _showError(String message) {
    final errorMessage = MessageModel(
      id: DateTime.now().toString(),
      text: '❌ $message',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'error',
      quickReplies: const ['🔄 Try Again', '🏠 Main Menu'],
    );
    _messages.add(errorMessage);
    notifyListeners();
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

  // Reset input type
  void resetInputType() {
    _currentInputType = null;
    notifyListeners();
  }

  // Clear session data
  void clearSession() {
    _currentSessionId = null;
    _sessionData = {};
    _currentInputType = null;
    _currentUserId = null;
    _currentEmail = null;
    _otpSent = false;
    _otpVerified = false;
    _otpError = null;
    _showResendOption = false;
    _timer?.cancel();
    notifyListeners();
  }

  // Clear chat and start over
  void clearChat() {
    _messages.clear();
    _error = null;
    _currentInputType = null;
    _currentSessionId = null;
    _sessionData = {};
    _isApiCallInProgress = false;
    _currentApiOperation = null;
    _currentUserId = null;
    _currentEmail = null;
    _otpSent = false;
    _otpVerified = false;
    _otpError = null;
    _showResendOption = false;
    _timer?.cancel();
    
    // Clear sorting and filtering
    _currentTicketFilter = null;
    _currentSortBy = null;
    _sortAscending = null;
    
    initializeChat();
    notifyListeners();
  }

  void addMessage(MessageModel message) {
    _messages.add(message);
    notifyListeners();
  }
}