// ticket_screen.dart - Complete updated version with image viewing
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/services/support_service.dart';
import 'chat_provider.dart';
import 'ticket_model.dart';
import 'message_model.dart';

// Extension for safe ticket ID display
extension TicketIdExtension on String {
  String get displayId {
    if (length >= 6) {
      return '#${substring(0, 6)}';
    } else {
      return '#$this';
    }
  }
}

// Color extension for opacity
extension ColorExtension on Color {
  Color withOpacityValue(double opacity) {
    return withValues(alpha: opacity);
  }
}

// Tickets List Screen - Enhanced with beautiful UI and API integration
class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({super.key});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  
  // Pagination
  int _currentPage = 0;
  int _totalTickets = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadTicketsFromApi();
  }

  Future<void> _loadTicketsFromApi({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 0;
        _tickets.clear();
      });
    }

    try {
      debugPrint('\n📋 ===== FETCHING TICKETS FROM API =====');
      debugPrint('Page: $_currentPage, Filter: $_selectedFilter');
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        throw Exception('User ID not found');
      }
      
      // Map filter to API status parameter
      String statusParam = 'OPEN'; // Default
      if (_selectedFilter != 'All') {
        switch (_selectedFilter) {
          case 'Open':
            statusParam = 'OPEN';
            break;
          case 'In Progress':
            statusParam = 'IN_PROGRESS';
            break;
          case 'Resolved':
            statusParam = 'RESOLVED';
            break;
          case 'Closed':
            statusParam = 'CLOSED';
            break;
        }
      }
      
      final result = await SupportService.getTodayTickets(status: statusParam);
  
      debugPrint('📊 API Response: ${jsonEncode(result)}');

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        List<TicketModel> fetchedTickets = [];
        
        // Parse tickets based on actual API response structure
        if (data['data'] != null && data['data'] is List) {
          final List<dynamic> ticketsData = data['data'];
          fetchedTickets = ticketsData.map((json) => TicketModel.fromJson(json)).toList();
          _totalTickets = data['total'] ?? ticketsData.length;
        } else if (data is List) {
          fetchedTickets = data.map((json) => TicketModel.fromJson(json)).toList();
          _totalTickets = fetchedTickets.length;
        }

        debugPrint('✅ Fetched ${fetchedTickets.length} tickets');
        
        setState(() {
          if (loadMore) {
            _tickets.addAll(fetchedTickets);
          } else {
            _tickets = fetchedTickets;
          }
          _hasMore = _tickets.length < _totalTickets;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception(result['message'] ?? 'Failed to fetch tickets');
      }
    } catch (e) {
      debugPrint('❌ Error loading tickets: $e');
      
      setState(() {
        _errorMessage = 'Failed to load tickets: $e';
        _isLoading = false;
        _isLoadingMore = false;
        _tickets = []; // Empty list on error
      });
    }
  }

  List<TicketModel> get _filteredTickets {
    if (_selectedFilter == 'All') return _tickets;
    
    return _tickets.where((ticket) {
      switch (_selectedFilter) {
        case 'Open':
          return ticket.isOpen || ticket.isInProgress;
        case 'Resolved':
          return ticket.isResolved;
        case 'Closed':
          return ticket.isClosed;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTicketsFromApi,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.orange.shade100,
                        child: Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Stats Summary
                    _buildStatsSummary(),
                    
                    // Tickets List
                    Expanded(
                      child: _filteredTickets.isEmpty
                          ? _buildNoTicketsForFilter()
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredTickets.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredTickets.length) {
                                  return _buildLoadMoreIndicator();
                                }
                                return _buildCompactTicketCard(_filteredTickets[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsSummary() {
    final openCount = _tickets.where((t) => t.isOpen || t.isInProgress).length;
    final resolvedCount = _tickets.where((t) => t.isResolved).length;
    final closedCount = _tickets.where((t) => t.isClosed).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactStat('Open', openCount, Colors.orange),
          _buildCompactStat('In Progress', openCount, Colors.blue),
          _buildCompactStat('Resolved', resolvedCount, Colors.green),
          _buildCompactStat('Total', _tickets.length, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTicketCard(TicketModel ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticket: ticket),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Left status indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ticket.statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ticket.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    ticket.statusIcon,
                    color: ticket.statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and ID
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ticket.id.displayId,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Description
                      Text(
                        ticket.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // Footer with status, priority and date
                      Row(
                        children: [
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ticket.statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ticket.statusIcon,
                                  size: 8,
                                  color: ticket.statusColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  ticket.statusText,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: ticket.statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          
                          // Priority chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ticket.priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ticket.priorityIcon,
                                  size: 8,
                                  color: ticket.priorityColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  ticket.priorityText,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: ticket.priorityColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Date
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatCompactDate(ticket.createdAt),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _hasMore
                ? TextButton(
                    onPressed: () => _loadTicketsFromApi(loadMore: true),
                    child: const Text('Load More'),
                  )
                : Text(
                    'No more tickets',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tickets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'Open', 'Resolved', 'Closed'].map((filter) {
            return ListTile(
              title: Text(filter),
              leading: Radio<String>(
                value: filter,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNoTicketsForFilter() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No ${_selectedFilter.toLowerCase()} tickets',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_number,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No tickets yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first support ticket',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Go to Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ticket Form Widget - Compact version for chat
class TicketFormWidget extends StatefulWidget {
  final Function(MessageModel) onTicketCreated;

  const TicketFormWidget({super.key, required this.onTicketCreated});

  @override
  State<TicketFormWidget> createState() => _TicketFormWidgetState();
}

class _TicketFormWidgetState extends State<TicketFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedPriority = 'MEDIUM';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isUploading = false;

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📝 Create Ticket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Brief summary',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(Icons.title, size: 18),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 8),
            
            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Detailed description',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(Icons.description, size: 18),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 8),
            
            // Priority Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                prefixIcon: Icon(Icons.priority_high, size: 18),
              ),
              value: _selectedPriority,
              items: _priorities.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(priority, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value!;
                });
              },
            ),
            
            const SizedBox(height: 8),
            
            // Image Attachment
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImages,
                    icon: _isUploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image, size: 16),
                    label: Text(
                      _selectedImages.isEmpty ? 'Add Images' : '${_selectedImages.length} selected',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            
            // Show selected images preview
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'LOW': return Colors.green;
      case 'MEDIUM': return Colors.orange;
      case 'HIGH': return Colors.deepOrange;
      case 'CRITICAL': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _pickImages() async {
    setState(() => _isUploading = true);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      
      if (result != null) {
        final validFiles = <File>[];
        
        for (var i = 0; i < result.files.length; i++) {
          final file = result.files[i];
          if (file.size <= 5 * 1024 * 1024) { // 5MB max
            validFiles.add(File(file.path!));
          }
        }
        
        setState(() {
          _selectedImages.addAll(validFiles);
          _isUploading = false;
        });
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      setState(() => _isUploading = false);
    }
  }

  Future<void> _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        debugPrint('\n📝 ===== CREATING TICKET =====');
        debugPrint('Title: ${_titleController.text}');
        debugPrint('Description: ${_descriptionController.text}');
        debugPrint('Priority: $_selectedPriority');
        
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? '';
        
        if (userId.isEmpty) {
          throw Exception('User ID not found. Please login again.');
        }
        
        final result = await SupportService.createTicket(
          title: _titleController.text,
          description: _descriptionController.text,
          priority: _selectedPriority,
          userId: userId,
          images: _selectedImages.isNotEmpty ? _selectedImages : null,
        );
        
        debugPrint('✅ API Response: ${jsonEncode(result)}');
        
        // Extract ticket ID based on API response structure
        String ticketId = 'N/A';
        if (result['data'] != null) {
          if (result['data']['ticketId'] != null) {
            ticketId = result['data']['ticketId'].toString();
          } else if (result['data']['data'] != null && result['data']['data']['ticketId'] != null) {
            ticketId = result['data']['data']['ticketId'].toString();
          }
        }
        
        final successMessage = MessageModel(
          id: DateTime.now().toString(),
          text: '✅ **Ticket Created!**\n\nID: `$ticketId`\nTitle: ${_titleController.text}',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'ticket_confirmation',
          ticketId: ticketId,
          quickReplies: const ['📋 View My Tickets', '🎫 Create Another', '🏠 Main Menu'],
        );
        
        widget.onTicketCreated(successMessage);
        
      } catch (e) {
        debugPrint('❌ Error: $e');
        
        final errorMessage = MessageModel(
          id: DateTime.now().toString(),
          text: '❌ Failed: ${e.toString().replaceAll('Exception:', '')}',
          isUser: false,
          timestamp: DateTime.now(),
          type: 'error',
          quickReplies: const ['🔄 Try Again', '🎫 Create Ticket', '🏠 Main Menu'],
        );
        
        widget.onTicketCreated(errorMessage);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Ticket Detail Screen - Enhanced with image viewing
class TicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Uint8List? _userImageBytes;
  Uint8List? _developerImageBytes;
  bool _isLoadingUserImage = false;
  bool _isLoadingDevImage = false;
  String? _userImageError;
  String? _devImageError;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    debugPrint('🖼️ ===== LOADING IMAGES FOR TICKET =====');
    debugPrint('Ticket ID: ${widget.ticket.id}');
    debugPrint('Has User Image: ${widget.ticket.hasUserImage}');
    debugPrint('Has Developer Image: ${widget.ticket.hasResUserImage}');
    
    // Load user image if available
    if (widget.ticket.hasUserImage) {
      await _loadUserImage();
    }
    
    // Load developer image if available
    if (widget.ticket.hasResUserImage) {
      await _loadResUserImage();
    }
  }

  Future<void> _loadUserImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUserImage = true;
      _userImageError = null;
    });

    try {
      final ticketId = int.tryParse(widget.ticket.id) ?? 0;
      if (ticketId == 0) {
        throw Exception('Invalid ticket ID');
      }

      debugPrint('📸 ===== LOADING USER IMAGE =====');
      debugPrint('Ticket ID: $ticketId');
      
      final result = await SupportService.viewTicketImageBase64(
        ticketId: ticketId,
        fileType: 'USER',
      );

      debugPrint('📊 Load user image result: $result');

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('📦 Image data: $data');
        
        if (data['imageBase64'] != null && data['imageBase64'].isNotEmpty) {
          final base64String = data['imageBase64'];
          debugPrint('🔤 Base64 string length: ${base64String.length}');
          debugPrint('🔤 Base64 preview: ${base64String.substring(0, min(50, base64String.length))}...');
          
          try {
            // Decode base64 to bytes
            final imageBytes = base64Decode(base64String);
            debugPrint('✅ Decoded image bytes length: ${imageBytes.length}');
            
            setState(() {
              _userImageBytes = imageBytes;
              _isLoadingUserImage = false;
              _userImageError = null;
            });
            
            debugPrint('✅ User image loaded and set in state successfully');
          } catch (e) {
            debugPrint('❌ Error decoding base64: $e');
            setState(() {
              _userImageError = 'Invalid image data';
              _isLoadingUserImage = false;
            });
          }
        } else {
          debugPrint('❌ No imageBase64 field in data');
          setState(() {
            _userImageError = 'No image data';
            _isLoadingUserImage = false;
          });
        }
      } else {
        String errorMsg = result['message'] ?? 'Failed to load image';
        debugPrint('❌ Failed to load image: $errorMsg');
        setState(() {
          _userImageError = errorMsg;
          _isLoadingUserImage = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user image: $e');
      if (!mounted) return;
      
      setState(() {
        _userImageError = 'Error loading image';
        _isLoadingUserImage = false;
      });
    }
  }

  Future<void> _loadResUserImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingDevImage = true;
      _devImageError = null;
    });

    try {
      final ticketId = int.tryParse(widget.ticket.id) ?? 0;
      if (ticketId == 0) {
        throw Exception('Invalid ticket ID');
      }

      debugPrint('📸 ===== LOADING DEVELOPER IMAGE =====');
      debugPrint('Ticket ID: $ticketId');
      
      final result = await SupportService.viewTicketImageBase64(
        ticketId: ticketId,
        fileType: 'DEVELOPER',
      );

      debugPrint('📊 Load developer image result: $result');

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('📦 Image data: $data');
        
        if (data['imageBase64'] != null && data['imageBase64'].isNotEmpty) {
          final base64String = data['imageBase64'];
          debugPrint('🔤 Base64 string length: ${base64String.length}');
          debugPrint('🔤 Base64 preview: ${base64String.substring(0, min(50, base64String.length))}...');
          
          try {
            // Decode base64 to bytes
            final imageBytes = base64Decode(base64String);
            debugPrint('✅ Decoded image bytes length: ${imageBytes.length}');
            
            setState(() {
              _developerImageBytes = imageBytes;
              _isLoadingDevImage = false;
              _devImageError = null;
            });
            
            debugPrint('✅ Developer image loaded and set in state successfully');
          } catch (e) {
            debugPrint('❌ Error decoding base64: $e');
            setState(() {
              _devImageError = 'Invalid image data';
              _isLoadingDevImage = false;
            });
          }
        } else {
          debugPrint('❌ No imageBase64 field in data');
          setState(() {
            _devImageError = 'No image data';
            _isLoadingDevImage = false;
          });
        }
      } else {
        String errorMsg = result['message'] ?? 'Failed to load image';
        debugPrint('❌ Failed to load image: $errorMsg');
        setState(() {
          _devImageError = errorMsg;
          _isLoadingDevImage = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading developer image: $e');
      if (!mounted) return;
      
      setState(() {
        _devImageError = 'Error loading image';
        _isLoadingDevImage = false;
      });
    }
  }

  Future<void> _viewImageFullScreen(Uint8List imageBytes, String title) async {
    if (!mounted) return;
    
    debugPrint('🖼️ Opening full screen image: $title, bytes: ${imageBytes.length}');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Image
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    child: Center(
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ Error displaying image: $error');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

  // Helper method for min
  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket ${widget.ticket.id.displayId}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Image view buttons if available
          if (widget.ticket.hasUserImage)
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: () {
                if (_userImageBytes != null) {
                  _viewImageFullScreen(_userImageBytes!, 'User Image');
                } else {
                  _loadUserImage();
                }
              },
              tooltip: 'View User Image',
            ),
          if (widget.ticket.hasResUserImage)
            IconButton(
              icon: const Icon(Icons.developer_mode),
              onPressed: () {
                if (_developerImageBytes != null) {
                  _viewImageFullScreen(_developerImageBytes!, 'Developer Image');
                } else {
                  _loadResUserImage();
                }
              },
              tooltip: 'View Developer Image',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadImages();
              try {
                context.read<ChatProvider>().fetchTicketDetails(int.parse(widget.ticket.id));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'track') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackTicketScreen(ticket: widget.ticket),
                  ),
                );
              } else if (value == 'refresh_images') {
                _loadImages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'track',
                child: Row(
                  children: [
                    Icon(Icons.track_changes, size: 18),
                    SizedBox(width: 8),
                    Text('Track Ticket'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh_images',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh Images'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            
            // Image Sections
            if (widget.ticket.hasUserImage || widget.ticket.hasResUserImage) ...[
              if (widget.ticket.hasUserImage)
                _buildImageSection(
                  title: 'User Image',
                  imageBytes: _userImageBytes,
                  isLoading: _isLoadingUserImage,
                  error: _userImageError,
                  fileType: 'USER',
                  onRefresh: _loadUserImage,
                  onTap: _userImageBytes != null 
                      ? () => _viewImageFullScreen(_userImageBytes!, 'User Image')
                      : null,
                ),
              const SizedBox(height: 16),
              if (widget.ticket.hasResUserImage)
                _buildImageSection(
                  title: 'Developer Image',
                  imageBytes: _developerImageBytes,
                  isLoading: _isLoadingDevImage,
                  error: _devImageError,
                  fileType: 'DEVELOPER',
                  onRefresh: _loadResUserImage,
                  onTap: _developerImageBytes != null 
                      ? () => _viewImageFullScreen(_developerImageBytes!, 'Developer Image')
                      : null,
                ),
              const SizedBox(height: 20),
            ],
            
            _buildDetails(),
            if (widget.ticket.currentResolutionSummary != null) ...[
              const SizedBox(height: 20),
              _buildResolutionSummary(),
            ],
            const SizedBox(height: 20),
            _buildMessages(context, widget.ticket.messages ?? []),
            const SizedBox(height: 20),
            _buildAddMessage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required Uint8List? imageBytes,
    required bool isLoading,
    required String? error,
    required String fileType,
    required VoidCallback onRefresh,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      fileType == 'USER' ? Icons.person : Icons.developer_mode,
                      size: 20,
                      color: fileType == 'USER' ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onRefresh,
                  tooltip: 'Refresh Image',
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 32, color: Colors.red.shade300),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: TextStyle(color: Colors.red.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (imageBytes != null)
              GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          imageBytes,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ Error displaying image in section: $error');
                            return Container(
                              height: 200,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Text('Failed to load image'),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to zoom',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text(
                        'No image available',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.ticket.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.ticket.statusIcon,
                        size: 18,
                        color: widget.ticket.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.ticket.statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.ticket.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.ticket.priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.ticket.priorityIcon,
                        size: 18,
                        color: widget.ticket.priorityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.ticket.priorityText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.ticket.priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              widget.ticket.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              widget.ticket.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Created by: ${widget.ticket.createdBy}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  widget.ticket.formattedCreatedAt,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            
            if (widget.ticket.assignedTo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.support_agent, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${widget.ticket.assignedTo}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            
            // Image indicators
            if (widget.ticket.hasUserImage || widget.ticket.hasResUserImage) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.image, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Attachments:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (widget.ticket.hasUserImage)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text('User Image'),
                        avatar: const Icon(Icons.person, size: 14),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ),
                  if (widget.ticket.hasResUserImage)
                    Chip(
                      label: const Text('Developer Image'),
                      avatar: const Icon(Icons.developer_mode, size: 14),
                      backgroundColor: Colors.green.shade50,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildTimelineItem(
              'Created',
              widget.ticket.formattedDateTime,
              Icons.create,
              Colors.blue,
            ),
            
            if (widget.ticket.resolvedAt != null)
              _buildTimelineItem(
                'Resolved',
                '${widget.ticket.resolvedAt!.day}/${widget.ticket.resolvedAt!.month}/${widget.ticket.resolvedAt!.year} ${widget.ticket.resolvedAt!.hour.toString().padLeft(2, '0')}:${widget.ticket.resolvedAt!.minute.toString().padLeft(2, '0')}',
                Icons.check_circle,
                Colors.green,
              ),
            
            if (widget.ticket.closedDate != null)
              _buildTimelineItem(
                'Closed',
                '${widget.ticket.closedDate!.day}/${widget.ticket.closedDate!.month}/${widget.ticket.closedDate!.year} ${widget.ticket.closedDate!.hour.toString().padLeft(2, '0')}:${widget.ticket.closedDate!.minute.toString().padLeft(2, '0')}',
                Icons.lock,
                Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionSummary() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Resolution Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                widget.ticket.currentResolutionSummary!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(BuildContext context, List<TicketMessage> messages) {
    if (messages.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No messages yet'),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...messages.map((msg) => _buildMessageItem(msg)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(TicketMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isFromUser ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: message.isInternal 
            ? Border.all(color: Colors.orange.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: message.isFromUser ? Colors.blue : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.formattedTime,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              if (message.isInternal) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Internal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          if (message.attachments != null && message.attachments!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: message.attachments!.map((att) {
                return Chip(
                  label: Text(att.split('/').last),
                  avatar: const Icon(Icons.attach_file, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddMessage(BuildContext context) {
    final controller = TextEditingController();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attachment feature coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        // Here you would call the API to add message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Message sent: ${controller.text}')),
                        );
                        controller.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Track Ticket Screen - For detailed tracking
class TrackTicketScreen extends StatelessWidget {
  final TicketModel ticket;

  const TrackTicketScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track ${ticket.id.displayId}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh tracking data
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusIndicator(
                          'Created',
                          Icons.create,
                          Colors.blue,
                          true,
                        ),
                        _buildStatusConnector(ticket.isInProgress || ticket.isResolved || ticket.isClosed),
                        _buildStatusIndicator(
                          'In Progress',
                          Icons.access_time,
                          Colors.orange,
                          ticket.isInProgress || ticket.isResolved || ticket.isClosed,
                        ),
                        _buildStatusConnector(ticket.isResolved || ticket.isClosed),
                        _buildStatusIndicator(
                          'Resolved',
                          Icons.check_circle,
                          Colors.green,
                          ticket.isResolved || ticket.isClosed,
                        ),
                        _buildStatusConnector(ticket.isClosed),
                        _buildStatusIndicator(
                          'Closed',
                          Icons.lock,
                          Colors.grey,
                          ticket.isClosed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tracking Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracking Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTrackingRow('Ticket ID', ticket.id),
                    _buildTrackingRow('Title', ticket.title),
                    _buildTrackingRow('Description', ticket.description),
                    _buildTrackingRow('Status', ticket.statusText),
                    _buildTrackingRow('Priority', ticket.priorityText),
                    _buildTrackingRow('Created', ticket.formattedDateTime),
                    
                    if (ticket.resolvedAt != null)
                      _buildTrackingRow(
                        'Resolved',
                        '${ticket.resolvedAt!.day}/${ticket.resolvedAt!.month}/${ticket.resolvedAt!.year} ${ticket.resolvedAt!.hour.toString().padLeft(2, '0')}:${ticket.resolvedAt!.minute.toString().padLeft(2, '0')}',
                      ),
                    
                    if (ticket.closedDate != null)
                      _buildTrackingRow(
                        'Closed',
                        '${ticket.closedDate!.day}/${ticket.closedDate!.month}/${ticket.closedDate!.year} ${ticket.closedDate!.hour.toString().padLeft(2, '0')}:${ticket.closedDate!.minute.toString().padLeft(2, '0')}',
                      ),
                  ],
                ),
              ),
            ),
            
            if (ticket.currentResolutionSummary != null) ...[
              const SizedBox(height: 16),
              
              // Resolution Summary Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resolution Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          ticket.currentResolutionSummary!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildStatusIndicator(String label, IconData icon, Color color, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : color,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? color : Colors.grey.shade400,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildTrackingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}