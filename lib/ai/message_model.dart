// message_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ticket_model.dart';

@immutable
class MessageModel {
  // Core properties
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? inputType;
  final String? validationError;
  final Map<String, dynamic>? tempData;
  
  // Optional properties
  final bool isError;
  final bool isAgent;
  final String? type;
  final TicketModel? ticket;
  final List<TicketModel>? tickets;
  final List<String>? quickReplies;
  final String? formField;
  final String? imageUrl;
  final bool isRead;
  final bool isDelivered;
  
  // Image data for viewing
  final Uint8List? imageData;
  final String? imageMimeType;
  
  // Ticket ID for success messages
  final String? ticketId;
  
  // Status properties
  final MessageStatus status;
  
  // Constructor with required and optional parameters
  const MessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isAgent = false,
    this.type,
    this.ticket,
    this.tickets,
    this.quickReplies,
    this.formField,
    this.imageUrl,
    this.isRead = false,
    this.isDelivered = false,
    this.status = MessageStatus.sent,
    this.inputType,
    this.validationError,
    this.tempData,
    this.imageData,
    this.imageMimeType,
    this.ticketId,
  });

  // Create a copy of this message with some fields changed
  MessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isError,
    bool? isAgent,
    String? type,
    TicketModel? ticket,
    List<TicketModel>? tickets,
    List<String>? quickReplies,
    String? formField,
    String? imageUrl,
    bool? isRead,
    bool? isDelivered,
    MessageStatus? status,
    String? inputType,
    String? validationError,
    Map<String, dynamic>? tempData,
    Uint8List? imageData,
    String? imageMimeType,
    String? ticketId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      isAgent: isAgent ?? this.isAgent,
      type: type ?? this.type,
      ticket: ticket ?? this.ticket,
      tickets: tickets ?? this.tickets,
      quickReplies: quickReplies ?? this.quickReplies,
      formField: formField ?? this.formField,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      status: status ?? this.status,
      inputType: inputType ?? this.inputType,
      validationError: validationError ?? this.validationError,
      tempData: tempData ?? this.tempData,
      imageData: imageData ?? this.imageData,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      ticketId: ticketId ?? this.ticketId,
    );
  }

  // Create message from JSON (for API responses)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? DateTime.now().toString(),
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isError: json['isError'] ?? false,
      isAgent: json['isAgent'] ?? false,
      type: json['type'],
      ticket: json['ticket'] != null 
          ? TicketModel.fromJson(json['ticket']) 
          : null,
      tickets: json['tickets'] != null
          ? (json['tickets'] as List)
              .map((t) => TicketModel.fromJson(t))
              .toList()
          : null,
      quickReplies: json['quickReplies'] != null
          ? List<String>.from(json['quickReplies'])
          : null,
      formField: json['formField'],
      imageUrl: json['imageUrl'],
      isRead: json['isRead'] ?? false,
      isDelivered: json['isDelivered'] ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
      ticketId: json['ticketId'],
    );
  }

  // Convert message to JSON (for sending to API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      'isAgent': isAgent,
      'type': type,
      'ticket': ticket?.toJson(),
      'tickets': tickets?.map((t) => t.toJson()).toList(),
      'quickReplies': quickReplies,
      'formField': formField,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'status': status.toString().split('.').last,
      'ticketId': ticketId,
    };
  }

  // Helper getters for UI
  bool get isBot => !isUser && !isAgent;
  bool get isWelcome => type == 'welcome';
  bool get isFAQ => type == 'faq';
  bool get isTicketList => type == 'ticket_list';
  bool get isTicketDetail => type == 'ticket_detail';
  bool get isFormRequest => type == 'form_request';
  bool get isTicketConfirmation => type == 'ticket_confirmation';
  bool get isTicketImage => type == 'ticket_image';
  bool get hasQuickReplies => quickReplies != null && quickReplies!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasImageData => imageData != null && imageData!.isNotEmpty;
  
  // Get formatted ticket ID for display
  String get displayTicketId {
    if (ticketId != null && ticketId!.isNotEmpty) {
      return ticketId!;
    }
    if (ticket != null) {
      return ticket!.id;
    }
    return 'N/A';
  }
  
  // Get formatted time for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
  
  // Get status icon for UI
  String get statusIcon {
    switch (status) {
      case MessageStatus.sending:
        return '⏳';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.read:
        return '👁';
      case MessageStatus.error:
        return '⚠️';
    }
  }
  
  // Get status color for UI
  Color get statusColor {
    switch (status) {
      case MessageStatus.sending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.blue;
      case MessageStatus.delivered:
        return Colors.green;
      case MessageStatus.read:
        return Colors.green;
      case MessageStatus.error:
        return Colors.red;
    }
  }
  
  // For equality and hashing
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel &&
        other.id == id &&
        other.text == text &&
        other.isUser == isUser &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => id.hashCode ^ text.hashCode ^ isUser.hashCode ^ timestamp.hashCode;
}

// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
}

// Quick reply model
class QuickReply {
  final String id;
  final String title;
  final String? value;
  final IconData? icon;
  final Color? color;
  
  const QuickReply({
    required this.id,
    required this.title,
    this.value,
    this.icon,
    this.color,
  });
  
  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      value: json['value'],
      icon: json['icon'] != null ? _getIconData(json['icon']) : null,
      color: json['color'] != null ? Color(json['color']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'icon': icon?.codePoint,
      'color': color?.value,
    };
  }
  
  static IconData? _getIconData(String iconName) {
    switch (iconName) {
      case 'create':
        return Icons.add_circle;
      case 'view':
        return Icons.list;
      case 'faq':
        return Icons.help;
      case 'agent':
        return Icons.support_agent;
      default:
        return null;
    }
  }
}