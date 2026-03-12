// ticket_model.dart
import 'package:flutter/material.dart';

@immutable
class TicketModel {
  // Core Properties from API
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Status & Priority
  final TicketStatus status;
  final TicketPriority priority;
  
  // User Information from API
  final String createdBy;
  final String? assignedTo;
  final String? department;
  
  // Additional Details from API - For tracking
  final String? currentResolutionSummary;
  final DateTime? resolvedAt;
  final DateTime? closedDate;
  
  // Image fields from API - ADD THESE
  final String? userFileName;
  final String? developerFileName;
  
  // Messages and Attachments
  final List<TicketMessage>? messages;
  final List<String>? attachmentUrls;
  final Map<String, dynamic>? customFields;
  
  // Metadata
  final DateTime? dueDate;
  final int? rating;
  final String? feedback;
  
  // Constructor with all API fields
  const TicketModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.department,
    this.currentResolutionSummary,
    this.resolvedAt,
    this.closedDate,
    this.userFileName, // ADD THIS
    this.developerFileName, // ADD THIS
    this.messages,
    this.attachmentUrls,
    this.customFields,
    this.dueDate,
    this.rating,
    this.feedback,
  });

  // Create from JSON (API response) - Maps directly from your API structure
  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      // Core fields from your API
      id: json['ticketId']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdBy: json['userid'] ?? json['createdBy'] ?? '',
      
      // Parse dates
      createdAt: json['createdDate'] != null 
          ? DateTime.parse(json['createdDate']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      resolvedAt: json['resolvedDate'] != null 
          ? DateTime.parse(json['resolvedDate']) 
          : null,
      closedDate: json['closedDate'] != null 
          ? DateTime.parse(json['closedDate']) 
          : null,
      dueDate: json['dueDate'] != null 
          ? DateTime.parse(json['dueDate']) 
          : null,
      
      // Status and Priority - Parse from strings
      status: _parseStatus(json['status']),
      priority: _parsePriority(json['priority']),
      
      // Tracking fields
      currentResolutionSummary: json['currentResolutionSummary'],
      
      // Image fields - ADD THESE
      userFileName: json['userFileName'],
      developerFileName: json['developerFileName'],
      
      // Optional fields
      assignedTo: json['assignedTo'],
      department: json['department'],
      
      // Messages and attachments
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => TicketMessage.fromJson(m))
              .toList()
          : null,
      attachmentUrls: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      customFields: json['customFields'],
      
      // Rating and feedback
      rating: json['rating'],
      feedback: json['feedback'],
    );
  }

  // Convert to JSON (for API requests) - Matches your PUT API structure
  Map<String, dynamic> toJson() {
    return {
      'ticketId': int.tryParse(id) ?? 0,
      'title': title,
      'description': description,
      'priority': priorityText.toUpperCase(),
      'status': statusText.toUpperCase().replaceAll(' ', '_'),
      'userid': createdBy,
      'clinicid': 'pcsadmin', // This comes from SupportService
      if (currentResolutionSummary != null) 
        'currentResolutionSummary': currentResolutionSummary,
    };
  }

  // Helper getters for UI
  bool get isOpen => status == TicketStatus.open;
  bool get isInProgress => status == TicketStatus.inProgress;
  bool get isResolved => status == TicketStatus.resolved;
  bool get isClosed => status == TicketStatus.closed;
  bool get isReopened => status == TicketStatus.reopened;
  bool get isOnHold => status == TicketStatus.onHold;
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());
  
  // Check if ticket has images
  bool get hasUserImage => userFileName != null && userFileName!.isNotEmpty;
  bool get hasResUserImage => developerFileName != null && developerFileName!.isNotEmpty;
  
  String get statusText {
    switch (status) {
      case TicketStatus.open:
        return 'OPEN';
      case TicketStatus.inProgress:
        return 'IN_PROGRESS';
      case TicketStatus.resolved:
        return 'RESOLVED';
      case TicketStatus.closed:
        return 'CLOSED';
      case TicketStatus.reopened:
        return 'REOPENED';
      case TicketStatus.onHold:
        return 'ON_HOLD';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case TicketStatus.open:
        return Colors.blue;
      case TicketStatus.inProgress:
        return Colors.orange;
      case TicketStatus.resolved:
        return Colors.green;
      case TicketStatus.closed:
        return Colors.grey;
      case TicketStatus.reopened:
        return Colors.purple;
      case TicketStatus.onHold:
        return Colors.red;
    }
  }
  
  IconData get statusIcon {
    switch (status) {
      case TicketStatus.open:
        return Icons.email_outlined;
      case TicketStatus.inProgress:
        return Icons.access_time;
      case TicketStatus.resolved:
        return Icons.check_circle_outline;
      case TicketStatus.closed:
        return Icons.lock_outline;
      case TicketStatus.reopened:
        return Icons.refresh;
      case TicketStatus.onHold:
        return Icons.pause_circle_outline;
    }
  }
  
  String get priorityText {
    switch (priority) {
      case TicketPriority.low:
        return 'LOW';
      case TicketPriority.medium:
        return 'MEDIUM';
      case TicketPriority.high:
        return 'HIGH';
      case TicketPriority.critical:
        return 'CRITICAL';
    }
  }
  
  Color get priorityColor {
    switch (priority) {
      case TicketPriority.low:
        return Colors.green;
      case TicketPriority.medium:
        return Colors.orange;
      case TicketPriority.high:
        return Colors.deepOrange;
      case TicketPriority.critical:
        return Colors.red;
    }
  }
  
  IconData get priorityIcon {
    switch (priority) {
      case TicketPriority.low:
        return Icons.arrow_downward;
      case TicketPriority.medium:
        return Icons.remove;
      case TicketPriority.high:
        return Icons.arrow_upward;
      case TicketPriority.critical:
        return Icons.warning;
    }
  }
  
  String get formattedCreatedAt {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  String get formattedResolvedAt {
    if (resolvedAt == null) return 'Not resolved';
    final now = DateTime.now();
    final difference = now.difference(resolvedAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  String get formattedClosedDate {
    if (closedDate == null) return 'Not closed';
    final now = DateTime.now();
    final difference = now.difference(closedDate!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
  
  String get formattedDateTime {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
  
  int get messageCount => messages?.length ?? 0;
  int get attachmentCount => attachmentUrls?.length ?? 0;
  
  // Create a copy with updated fields (for local updates)
  TicketModel copyWith({
    String? title,
    String? description,
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    String? currentResolutionSummary,
    DateTime? resolvedAt,
    DateTime? closedDate,
    String? userFileName,
    String? developerFileName,
    List<TicketMessage>? messages,
    List<String>? attachmentUrls,
    int? rating,
    String? feedback,
  }) {
    return TicketModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: DateTime.now(),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      department: department,
      currentResolutionSummary: currentResolutionSummary ?? this.currentResolutionSummary,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedDate: closedDate ?? this.closedDate,
      userFileName: userFileName ?? this.userFileName,
      developerFileName: developerFileName ?? this.developerFileName,
      messages: messages ?? this.messages,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      customFields: customFields,
      dueDate: dueDate,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
    );
  }

  // Static parsing helpers that match your API exactly
  static TicketStatus _parseStatus(String? status) {
    if (status == null) return TicketStatus.open;
    switch (status.toUpperCase()) {
      case 'OPEN':
        return TicketStatus.open;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return TicketStatus.inProgress;
      case 'RESOLVED':
        return TicketStatus.resolved;
      case 'CLOSED':
        return TicketStatus.closed;
      case 'REOPENED':
        return TicketStatus.reopened;
      case 'ON_HOLD':
      case 'ONHOLD':
        return TicketStatus.onHold;
      default:
        return TicketStatus.open;
    }
  }

  static TicketPriority _parsePriority(String? priority) {
    if (priority == null) return TicketPriority.medium;
    switch (priority.toUpperCase()) {
      case 'LOW':
        return TicketPriority.low;
      case 'MEDIUM':
        return TicketPriority.medium;
      case 'HIGH':
        return TicketPriority.high;
      case 'CRITICAL':
        return TicketPriority.critical;
      default:
        return TicketPriority.medium;
    }
  }
}

// Ticket Status Enum - Matches your API status values
enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
  reopened,
  onHold,
}

// Ticket Priority Enum - Matches your API priority values
enum TicketPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  final String text;

  const TicketPriority(this.text);

  Color get color {
    switch (this) {
      case TicketPriority.low:
        return Colors.green;
      case TicketPriority.medium:
        return Colors.orange;
      case TicketPriority.high:
        return Colors.deepOrange;
      case TicketPriority.critical:
        return Colors.red;
    }
  }
}

// Ticket Category Model (if needed)
class TicketCategory {
  final String id;
  final String name;
  final String? description;
  final IconData? icon;
  
  const TicketCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });
  
  factory TicketCategory.fromJson(Map<String, dynamic> json) {
    return TicketCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'] != null ? _getIconData(json['icon']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon?.codePoint,
    };
  }
  
  static IconData? _getIconData(String iconName) {
    switch (iconName) {
      case 'bug':
        return Icons.bug_report;
      case 'feature':
        return Icons.new_releases;
      case 'question':
        return Icons.help;
      case 'payment':
        return Icons.payment;
      case 'account':
        return Icons.person;
      default:
        return Icons.category;
    }
  }
}

// Ticket Message Model (for conversation within ticket)
class TicketMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isInternal;
  final List<String>? attachments;
  final bool isFromUser;
  
  const TicketMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isInternal = false,
    this.attachments,
    required this.isFromUser,
  });
  
  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'] ?? DateTime.now().toString(),
      text: json['text'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isInternal: json['isInternal'] ?? false,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      isFromUser: json['isFromUser'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
      'isInternal': isInternal,
      'attachments': attachments,
      'isFromUser': isFromUser,
    };
  }
  
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}