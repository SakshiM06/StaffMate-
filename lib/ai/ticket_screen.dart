// ticket_screen.dart - Fixed version: queryType mapping + inline attachments
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

extension TicketIdExtension on String {
  String get displayId {
    if (length >= 6) return '#${substring(0, 6)}';
    return '#$this';
  }
}

extension ColorExtension on Color {
  Color withOpacityValue(double opacity) => withValues(alpha: opacity);
}

// ─── Fullscreen Image Viewer ─────────────────────────────────────────────────
class FullscreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;
  final String title;

  const FullscreenImageViewer({
    super.key,
    required this.imageBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            onPressed: () {},
            tooltip: 'Pinch to zoom',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          panEnabled: true,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline Image Widget (auto-fetch, tap-to-fullscreen) ─────────────────────
class TicketImageWidget extends StatefulWidget {
  final int ticketId;
  final String fileType; // 'USER' or 'DEVELOPER'
  final String label;

  const TicketImageWidget({
    super.key,
    required this.ticketId,
    required this.fileType,
    required this.label,
  });

  @override
  State<TicketImageWidget> createState() => _TicketImageWidgetState();
}

class _TicketImageWidgetState extends State<TicketImageWidget> {
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _hasError = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final result = await SupportService.viewTicketImageBase64(
        ticketId: widget.ticketId,
        fileType: widget.fileType.toUpperCase(),
      );

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final raw = result['data']['imageBase64']?.toString() ?? '';
        if (raw.isNotEmpty) {
          // Strip data URI prefix if present
          final pure = raw.contains(',') ? raw.split(',').last : raw;
          final bytes = base64Decode(pure);
          setState(() {
            _imageBytes = bytes;
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _hasError = true;
        _errorMsg = result['message'] ?? 'No image data';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMsg = 'Failed to load';
        });
      }
    }
  }

  void _openFullscreen() {
    if (_imageBytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageBytes: _imageBytes!,
          title: '${widget.label} — Ticket #${widget.ticketId}',
        ),
      ),
    );
  }

  Color get _accentColor =>
      widget.fileType == 'USER' ? Colors.blue : Colors.green;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Icon(
              widget.fileType == 'USER' ? Icons.person : Icons.developer_mode,
              size: 14,
              color: _accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_loading)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_hasError || _imageBytes == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.image_not_supported, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  _errorMsg ?? 'No image available',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          // Thumbnail — tap to fullscreen
          GestureDetector(
            onTap: _openFullscreen,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _imageBytes!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.grey.shade100,
                      child: const Center(child: Text('Failed to display image')),
                    ),
                  ),
                ),
                // "Tap to zoom" badge
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Tap to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Tickets List Screen ──────────────────────────────────────────────────────
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
      String statusParam = 'OPEN';
      if (_selectedFilter != 'All') {
        switch (_selectedFilter) {
          case 'Open':
            statusParam = 'OPEN';
          case 'In Progress':
            statusParam = 'IN_PROGRESS';
          case 'Resolved':
            statusParam = 'RESOLVED';
          case 'Closed':
            statusParam = 'CLOSED';
        }
      }

      final result = await SupportService.getTodayTickets(status: statusParam);

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        List<TicketModel> fetchedTickets = [];

        if (data['data'] != null && data['data'] is List) {
          fetchedTickets = (data['data'] as List)
              .map((json) => TicketModel.fromJson(json))
              .toList();
          _totalTickets = data['total'] ?? fetchedTickets.length;
        } else if (data is List) {
          fetchedTickets = data.map((json) => TicketModel.fromJson(json)).toList();
          _totalTickets = fetchedTickets.length;
        }

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
      setState(() {
        _errorMessage = 'Failed to load tickets: $e';
        _isLoading = false;
        _isLoadingMore = false;
        _tickets = [];
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

  // ── Helper: display name (queryType takes priority over title) ──
  String _ticketDisplayName(TicketModel ticket) =>
      (ticket.queryType?.isNotEmpty == true ? ticket.queryType! : ticket.title).trim();

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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTicketsFromApi),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog),
        ],
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
                              child: Text(_errorMessage!,
                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                            ),
                          ],
                        ),
                      ),
                    _buildStatsSummary(),
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
        Text(count.toString(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildCompactTicketCard(TicketModel ticket) {
    final displayName = _ticketDisplayName(ticket);

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ticket.statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ticket.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(ticket.statusIcon, color: ticket.statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ticket.id.displayId,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.description,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildMiniChip(ticket.statusText, ticket.statusColor, ticket.statusIcon),
                          const SizedBox(width: 6),
                          _buildMiniChip(ticket.priorityText, ticket.priorityColor, ticket.priorityIcon),
                          // Attachment indicator
                          if (ticket.hasUserImage || ticket.hasResUserImage) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file, size: 8, color: Colors.purple),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${(ticket.hasUserImage ? 1 : 0) + (ticket.hasResUserImage ? 1 : 0)}',
                                    style: const TextStyle(fontSize: 8, color: Colors.purple),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 10, color: Colors.grey.shade400),
                              const SizedBox(width: 2),
                              Text(
                                _formatCompactDate(ticket.createdAt),
                                style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatCompactDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : _hasMore
                ? TextButton(
                    onPressed: () => _loadTicketsFromApi(loadMore: true),
                    child: const Text('Load More'))
                : Text('No more tickets',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                  setState(() => _selectedFilter = value!);
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
          Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('No ${_selectedFilter.toLowerCase()} tickets',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.confirmation_number, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          const Text('No tickets yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Create your first support ticket',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Go to Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ticket Form Widget ───────────────────────────────────────────────────────
class TicketFormWidget extends StatefulWidget {
  final Function(MessageModel) onTicketCreated;
  const TicketFormWidget({super.key, required this.onTicketCreated});

  @override
  State<TicketFormWidget> createState() => _TicketFormWidgetState();
}

class _TicketFormWidgetState extends State<TicketFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Use queryType dropdown instead of free-text title
  String? _selectedQueryType;
  String _selectedPriority = 'MEDIUM';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isUploading = false;

  static const List<String> _queryTypes = [
    'Access Request',
    'Billing Issue',
    'Data Correction Issue',
    'Feature Request',
    'General Query',
    'Network Issue',
    'Password Request',
    'Software Issue',
    'Other',
  ];

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
            const Text('📝 Create Ticket',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // ── Query Type Dropdown ──
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Query Type',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                prefixIcon: Icon(Icons.category, size: 18),
              ),
              value: _selectedQueryType,
              hint: const Text('Select query type'),
              items: _queryTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedQueryType = v),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),

            // ── Description ──
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
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),

            // ── Priority Dropdown ──
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                prefixIcon: Icon(Icons.priority_high, size: 18),
              ),
              value: _selectedPriority,
              items: _priorities.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _getPriorityColor(p), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(p, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedPriority = v!),
            ),
            const SizedBox(height: 8),

            // ── Image Attachment ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImages,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image, size: 16),
                    label: Text(
                      _selectedImages.isEmpty
                          ? 'Add Images'
                          : '${_selectedImages.length} selected',
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
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),

            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
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
                            child: Image.file(_selectedImages[index], fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImages.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child:
                                  const Icon(Icons.close, size: 12, color: Colors.white),
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

  Color _getPriorityColor(String p) {
    switch (p) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.deepOrange;
      case 'CRITICAL':
        return Colors.red;
      default:
        return Colors.grey;
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
        final valid = result.files
            .where((f) => f.size <= 5 * 1024 * 1024)
            .map((f) => File(f.path!))
            .toList();
        setState(() => _selectedImages.addAll(valid));
      }
    } catch (_) {}
    setState(() => _isUploading = false);
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) throw Exception('User ID not found. Please login again.');

      final result = await SupportService.createTicket(
        queryType: _selectedQueryType!,
        description: _descriptionController.text,
        priority: _selectedPriority,
        userId: userId,
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
      );

      String ticketId = 'N/A';
      if (result['data'] != null) {
        ticketId =
            (result['data']['ticketId'] ?? result['data']['data']?['ticketId'] ?? 'N/A')
                .toString();
      }

      widget.onTicketCreated(MessageModel(
        id: DateTime.now().toString(),
        text: '✅ **Ticket Created!**\n\nID: `$ticketId`\nQuery Type: ${_selectedQueryType!}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'ticket_confirmation',
        ticketId: ticketId,
        quickReplies: const ['📋 View My Tickets', '🎫 Create Another', '🏠 Main Menu'],
      ));
    } catch (e) {
      widget.onTicketCreated(MessageModel(
        id: DateTime.now().toString(),
        text: '❌ Failed: ${e.toString().replaceAll('Exception:', '')}',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
        quickReplies: const ['🔄 Try Again', '🎫 Create Ticket', '🏠 Main Menu'],
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

// ─── Ticket Detail Screen ─────────────────────────────────────────────────────
class TicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  /// Display name: prefer queryType over title
  String get _displayName =>
      (widget.ticket.queryType?.isNotEmpty == true
              ? widget.ticket.queryType!
              : widget.ticket.title)
          .trim();

  @override
  Widget build(BuildContext context) {
    final ticketIdInt = int.tryParse(widget.ticket.id);
    final hasAttachments =
        widget.ticket.hasUserImage || widget.ticket.hasResUserImage;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket ${widget.ticket.id.displayId}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              try {
                context
                    .read<ChatProvider>()
                    .fetchTicketDetails(int.parse(widget.ticket.id));
              } catch (_) {}
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'track') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TrackTicketScreen(ticket: widget.ticket)),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'track',
                child:
                    Row(children: [Icon(Icons.track_changes, size: 18), SizedBox(width: 8), Text('Track Ticket')]),
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
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            // ── Attachments Section (inline, combined) ──
            if (hasAttachments && ticketIdInt != null) ...[
              _buildAttachmentsSection(ticketIdInt),
              const SizedBox(height: 16),
            ],

            _buildDetails(),
            if (widget.ticket.currentResolutionSummary != null) ...[
              const SizedBox(height: 16),
              _buildResolutionSummary(),
            ],
            const SizedBox(height: 16),
            _buildMessages(widget.ticket.messages ?? []),
            const SizedBox(height: 16),
            _buildAddMessage(context),
          ],
        ),
      ),
    );
  }

  // ── Combined attachments card ──
  Widget _buildAttachmentsSection(int ticketIdInt) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file, size: 18, color: Color(0xFF1A237E)),
                const SizedBox(width: 8),
                const Text(
                  'Attachments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(widget.ticket.hasUserImage ? 1 : 0) + (widget.ticket.hasResUserImage ? 1 : 0)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // User image
            if (widget.ticket.hasUserImage) ...[
              TicketImageWidget(
                ticketId: ticketIdInt,
                fileType: 'USER',
                label: 'User Attachment',
              ),
            ],

            if (widget.ticket.hasUserImage && widget.ticket.hasResUserImage)
              const SizedBox(height: 16),

            // Developer image
            if (widget.ticket.hasResUserImage) ...[
              TicketImageWidget(
                ticketId: ticketIdInt,
                fileType: 'DEVELOPER',
                label: 'Developer Attachment',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusBadge(widget.ticket.statusColor, widget.ticket.statusIcon,
                    widget.ticket.statusText),
                const Spacer(),
                _buildStatusBadge(widget.ticket.priorityColor, widget.ticket.priorityIcon,
                    widget.ticket.priorityText),
              ],
            ),
            const SizedBox(height: 16),

            // ── Query Type (primary label) ──
            if (widget.ticket.queryType?.isNotEmpty == true) ...[
              Row(
                children: [
                  Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Query Type',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.ticket.queryType!,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                widget.ticket.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
            ],

            Text(
              widget.ticket.description,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Created by: ${widget.ticket.createdBy}',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(widget.ticket.formattedCreatedAt,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            if (widget.ticket.assignedTo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.support_agent, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Assigned to: ${widget.ticket.assignedTo}',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTimelineItem(
                'Created', widget.ticket.formattedDateTime, Icons.create, Colors.blue),
            if (widget.ticket.resolvedAt != null)
              _buildTimelineItem('Resolved', _fmtDate(widget.ticket.resolvedAt!),
                  Icons.check_circle, Colors.green),
            if (widget.ticket.closedDate != null)
              _buildTimelineItem('Closed', _fmtDate(widget.ticket.closedDate!),
                  Icons.lock, Colors.grey),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _buildTimelineItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration:
                BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text('Resolution Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    fontSize: 13, color: Colors.green.shade800, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(List<TicketMessage> messages) {
    if (messages.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No messages yet')),
        ),
      );
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conversation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        color: message.isFromUser
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.grey.shade100,
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
              Text(message.senderName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: message.isFromUser ? Colors.blue : Colors.black87)),
              const SizedBox(width: 8),
              Text(message.formattedTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              if (message.isInternal) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Internal',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(message.text,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildAddMessage(BuildContext context) {
    final controller = TextEditingController();
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attachment feature coming soon!')),
                    ),
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Message sent: ${controller.text}')),
                        );
                        controller.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

// ─── Track Ticket Screen ──────────────────────────────────────────────────────
class TrackTicketScreen extends StatelessWidget {
  final TicketModel ticket;
  const TrackTicketScreen({super.key, required this.ticket});

  String get _displayName =>
      (ticket.queryType?.isNotEmpty == true ? ticket.queryType! : ticket.title).trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track ${ticket.id.displayId}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Status tracker bar ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusIndicator('Created', Icons.create, Colors.blue, true),
                    _buildConnector(ticket.isInProgress || ticket.isResolved || ticket.isClosed),
                    _buildStatusIndicator('In Progress', Icons.access_time, Colors.orange,
                        ticket.isInProgress || ticket.isResolved || ticket.isClosed),
                    _buildConnector(ticket.isResolved || ticket.isClosed),
                    _buildStatusIndicator('Resolved', Icons.check_circle, Colors.green,
                        ticket.isResolved || ticket.isClosed),
                    _buildConnector(ticket.isClosed),
                    _buildStatusIndicator(
                        'Closed', Icons.lock, Colors.grey, ticket.isClosed),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tracking Details ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tracking Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildRow('Ticket ID', ticket.id),
                    _buildRow('Query Type', _displayName), // ← uses queryType
                    _buildRow('Description', ticket.description),
                    _buildRow('Status', ticket.statusText),
                    _buildRow('Priority', ticket.priorityText),
                    _buildRow('Created', ticket.formattedDateTime),
                    if (ticket.resolvedAt != null)
                      _buildRow('Resolved', _fmtDate(ticket.resolvedAt!)),
                    if (ticket.closedDate != null)
                      _buildRow('Closed', _fmtDate(ticket.closedDate!)),
                  ],
                ),
              ),
            ),

            if (ticket.currentResolutionSummary != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resolution Summary',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                              fontSize: 14, color: Colors.green.shade800, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Inline Attachments in Track view ──
            if ((ticket.hasUserImage || ticket.hasResUserImage) &&
                int.tryParse(ticket.id) != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.attach_file, size: 18, color: Color(0xFF1A237E)),
                          SizedBox(width: 8),
                          Text('Attachments',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (ticket.hasUserImage)
                        TicketImageWidget(
                          ticketId: int.parse(ticket.id),
                          fileType: 'USER',
                          label: 'User Attachment',
                        ),
                      if (ticket.hasUserImage && ticket.hasResUserImage)
                        const SizedBox(height: 16),
                      if (ticket.hasResUserImage)
                        TicketImageWidget(
                          ticketId: int.parse(ticket.id),
                          fileType: 'DEVELOPER',
                          label: 'Developer Attachment',
                        ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
      String label, IconData icon, Color color, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isActive ? Colors.white : color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 10,
              color: isActive ? color : Colors.grey.shade400,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      color: isActive ? Colors.green : Colors.grey.shade300,
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}