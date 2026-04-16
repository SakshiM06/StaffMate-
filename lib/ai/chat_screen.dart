// chat_screen.dart - Complete version with FAQ support
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/ai/chat_screen.dart' as _descriptionController;
import 'package:staff_mate/ai/ticket_model.dart';
import 'package:staff_mate/ai/ticket_screen.dart';
import 'package:staff_mate/services/support_service.dart';
import 'chat_provider.dart';
import 'message_model.dart';

extension TicketIdExtension on String {
  String get displayId {
    if (length >= 6) return '#${substring(0, 6)}';
    return '#$this';
  }
}

// ── Helper: prefer queryType over title ──────────────────────────────────────
String _ticketDisplayName(TicketModel ticket) =>
    (ticket.queryType?.isNotEmpty == true ? ticket.queryType! : ticket.title)
        .trim();

// ─── ChatScreen root ──────────────────────────────────────────────────────────
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const Scaffold(body: _ChatBody()),
    );
  }
}

// ─── Fullscreen Image Viewer ──────────────────────────────────────────────────
class _FullscreenImageViewer extends StatelessWidget {
  final Uint8List imageData;
  final String label;

  const _FullscreenImageViewer({required this.imageData, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(imageData, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ─── Inline Ticket Image (auto-fetch, expand/collapse, fullscreen on tap) ─────
class _InlineTicketImage extends StatefulWidget {
  final int ticketId;
  final String fileType;
  final String label;

  const _InlineTicketImage({
    required this.ticketId,
    required this.fileType,
    required this.label,
  });

  @override
  State<_InlineTicketImage> createState() => _InlineTicketImageState();
}

class _InlineTicketImageState extends State<_InlineTicketImage> {
  Uint8List? _imageData;
  bool _loading = true;
  bool _hasError = false;
  bool _expanded = false;

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
          final pure = raw.contains(',') ? raw.split(',').last : raw;
          final bytes = base64Decode(pure);
          setState(() {
            _imageData = bytes;
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _hasError = true;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  void _openFullscreen() {
    if (_imageData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          imageData: _imageData!,
          label: '${widget.label} — Ticket #${widget.ticketId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_hasError || _imageData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.image_not_supported, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text('No ${widget.label} image',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.image, size: 13, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _openFullscreen,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _imageData!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text('Tap to expand',
                          style: TextStyle(color: Colors.white, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Modern Gradient App Bar ──────────────────────────────────────────────────
class _ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ModernAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: AppBar(
        title: Row(
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.support_agent,
                        color: Color(0xFF1A237E), size: 24),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Support Assistant',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.green.shade400.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Online • Ready to help',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildActionButton(
            icon: Icons.refresh,
            onPressed: () {
              context.read<ChatProvider>().clearChat();
              _showSnackBar(context, 'Chat restarted');
            },
            tooltip: 'Restart Chat',
          ),
          _buildActionButton(
            icon: Icons.close,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required String tooltip}) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          tooltip: tooltip),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ─── Main Chat Body ───────────────────────────────────────────────────────────
class _ChatBody extends StatefulWidget {
  const _ChatBody();

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChatHistory();

      context.read<ChatProvider>().focusKeyboardStream.listen((event) {
        if (event == 'focus_text') {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) FocusScope.of(context).requestFocus(_focusNode);
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade50, Colors.white],
            ),
          ),
          child: Column(
            children: [
              const _ModernAppBar(),
              Expanded(
                child: provider.isLoading && provider.messages.isEmpty
                    ? _buildShimmerLoading()
                    : provider.messages.isEmpty
                        ? _buildModernEmptyState(context)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.messages.length,
                            itemBuilder: (context, index) {
                              final message = provider.messages[index];
                              return _ModernMessageBubble(
                                message: message,
                                onOptionSelected: (reply) =>
                                    _handleQuickReply(reply, provider),
                                index: index,
                              );
                            },
                          ),
              ),
              if (provider.isBotTyping) const _ModernTypingIndicator(),
              _buildModernInputArea(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                          colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5)
                      ],
                    ),
                    child: const Icon(Icons.support_agent,
                        size: 60, color: Color(0xFF1A237E)),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Hello! How can we help you today?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 8),
            Text('Choose an option below to get started',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildModernActionChip('🎫 Create Ticket', Colors.blue, context),
                  _buildModernActionChip('📋 View Tickets', Colors.green, context),
                  _buildModernActionChip('🔍 Track Ticket', Colors.orange, context),
                  _buildModernActionChip('🔐 Password Reset', Colors.red, context),
                  _buildModernActionChip('📚 FAQ', Colors.purple, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionChip(
      String label, Color color, BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: () => _handleQuickReply(label, context.read<ChatProvider>()),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildModernInputArea(ChatProvider provider) {
    final isTyping = _textController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.mic, color: Colors.grey.shade700),
              onPressed: () =>
                  _showSnackBar(context, 'Voice input coming soon!'),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isTyping ? Colors.blue.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _getHintText(provider.currentInputType),
                  hintStyle: TextStyle(
                    color: provider.currentInputType != null
                        ? Colors.blue.shade700
                        : Colors.grey.shade500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                  prefixIcon: provider.currentInputType != null
                      ? Icon(_getInputIcon(provider.currentInputType!),
                          color: Colors.blue.shade700)
                      : null,
                ),
                onSubmitted: (_) => _sendMessage(provider),
                textInputAction: TextInputAction.send,
                obscureText: provider.currentInputType == 'new_password' ||
                    provider.currentInputType == 'new_password_input',
                keyboardType:
                    _getKeyboardType(provider.currentInputType),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTyping
                    ? [Colors.green, Colors.green.shade700]
                    : [const Color(0xFF1A237E), const Color(0xFF283593)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: (isTyping ? Colors.green : const Color(0xFF1A237E))
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1)
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment:
                index.isEven ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (index.isEven) ...[
                Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Colors.grey, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16))),
              if (index.isOdd) ...[
                const SizedBox(width: 8),
                Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Colors.grey, shape: BoxShape.circle)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _handleQuickReply(String reply, ChatProvider provider) {
    provider.processOption(reply);
  }

  void _sendMessage(ChatProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {});
    if (provider.currentInputType != null) {
      provider.processTextInput(text);
    } else {
      provider.processOption(text);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _getHintText(String? inputType) {
    switch (inputType) {
      case 'user_id_input': return 'Enter your User ID...';
      case 'email': return 'Enter your email address...';
      case 'otp': return 'Enter 6-digit OTP...';
      case 'new_password':
      case 'new_password_input': return 'Enter new password...';
      default: return 'Type your message...';
    }
  }

  IconData _getInputIcon(String inputType) {
    switch (inputType) {
      case 'user_id_input': return Icons.person_outline;
      case 'email': return Icons.email_outlined;
      case 'otp': return Icons.lock_outline;
      case 'new_password':
      case 'new_password_input': return Icons.vpn_key;
      default: return Icons.message;
    }
  }

  TextInputType _getKeyboardType(String? inputType) {
    switch (inputType) {
      case 'email':            return TextInputType.emailAddress;
      case 'otp':              return TextInputType.number;
      case 'new_password':
      case 'new_password_input': return TextInputType.visiblePassword;
      default:                 return TextInputType.text;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// ─── Modern Message Bubble ────────────────────────────────────────────────────
class _ModernMessageBubble extends StatelessWidget {
  final MessageModel message;
  final Function(String) onOptionSelected;
  final int index;

  const _ModernMessageBubble({
    required this.message,
    required this.onOptionSelected,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) _buildAvatar(Icons.support_agent, Colors.blue),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUser
                            ? [
                                const Color(0xFF1A237E),
                                const Color(0xFF283593)
                              ]
                            : [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(),
                        const SizedBox(height: 4),
                        Text(
                          message.formattedTime,
                          style: TextStyle(
                              fontSize: 10,
                              color: isUser
                                  ? Colors.white70
                                  : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 8),
                  _buildAvatar(Icons.person, Colors.green),
                ],
              ],
            ),

            // ── Quick Replies ──
            // Don't show quick replies for FAQ messages to avoid duplicates
            if (!isUser && message.hasQuickReplies && 
                message.type != 'faq_answer' && 
                message.type != 'faq_menu') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.quickReplies!
                      .map((o) => _buildModernOptionChip(o))
                      .toList(),
                ),
              ),
            ],

            // ── FAQ MENU ──
            if (!isUser && message.type == 'faq_menu') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _buildFaqMenu(),
              ),
            ],

            // ── FAQ ANSWER ──
            if (!isUser && message.type == 'faq_answer') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (message.hasQuickReplies)
                        Wrap(
                          spacing: 8,
                          children: message.quickReplies!
                              .map((reply) => _buildFaqAnswerFooter(reply))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Ticket Form ──
            if (!isUser && message.type == 'ticket_form') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _ModernTicketForm(
                  onSubmit: (queryType, module, description, priority, images) async {
                    final provider = context.read<ChatProvider>();
                    final loadingMsg = MessageModel(
                      id: DateTime.now().toString(),
                      text: '⏳ Creating your ticket...',
                      isUser: false,
                      timestamp: DateTime.now(),
                      type: 'loading',
                    );
                    provider.addMessage(loadingMsg);

                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getString('userId') ?? '';
    final fullTitle = '$queryType - $module';
                      final result = await SupportService.createTicket(
                        queryType: queryType,
                        description: description,
                        priority: priority,
                        userId: userId,
                        images: images.isNotEmpty ? images : null,
                      );

                      String ticketId = 'N/A';
                      if (result['data'] != null) {
                        ticketId = (result['data']['ticketId'] ??
                                result['data']['data']?['ticketId'] ??
                                'N/A')
                            .toString();
                      }

                      provider.messages.removeLast();
                      provider.addMessage(MessageModel(
                        id: DateTime.now().toString(),
                        text: '✅ **Ticket Created Successfully!**\n\n'
                            '**Ticket ID:** `$ticketId`\n'
                            '**Query Type:** $queryType\n'
                            '**Priority:** $priority\n\n'
                            '📧 A confirmation has been sent to your registered email address.\n'
        'Kindly check your inbox (and spam folder if needed) for details.\n\n'
        'Our support team will look into this shortly.',
                        isUser: false,
                        timestamp: DateTime.now(),
                        type: 'ticket_confirmation',
                        ticketId: ticketId,
                        quickReplies: const [
                          '📋 View My Tickets',
                          '🎫 Create Another',
                          '🏠 Main Menu',
                        ],
                      ));
                    } catch (e) {
                      provider.messages.removeLast();
                      provider.addMessage(MessageModel(
                        id: DateTime.now().toString(),
                        text: '❌ **Failed to create ticket**\n\n'
                            'Error: ${e.toString().replaceAll('Exception:', '')}\n\n'
                            'Please try again.',
                        isUser: false,
                        timestamp: DateTime.now(),
                        type: 'error',
                        quickReplies: const [
                          '🔄 Try Again',
                          '🎫 Create Ticket',
                          '🏠 Main Menu',
                        ],
                      ));
                    }
                  },
                  onCancel: () {
                    context.read<ChatProvider>().addMessage(MessageModel(
                      id: DateTime.now().toString(),
                      text: '❌ Ticket creation cancelled.',
                      isUser: false,
                      timestamp: DateTime.now(),
                      type: 'info',
                      quickReplies: const ['🎫 Create Ticket', '🏠 Main Menu'],
                    ));
                  },
                ),
              ),
            ],

            // ── Status Selection for View Tickets ──
            if (!isUser &&
                message.type == 'status_selection' &&
                message.tempData?['action'] == 'view_tickets_by_status') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _buildStatusOptionsContainer(
                  title: 'View Tickets by Status',
                  icon: Icons.filter_list,
                  options: [
                    _buildStatusOption('OPEN', Icons.email, Colors.blue,
                        '📋 OPEN Tickets'),
                    _buildStatusOption('IN_PROGRESS', Icons.access_time,
                        Colors.orange, '📋 IN_PROGRESS Tickets'),
                    _buildStatusOption('RESOLVED', Icons.check_circle,
                        Colors.green, '📋 RESOLVED Tickets'),
                    _buildStatusOption(
                        'CLOSED', Icons.lock, Colors.grey, '📋 CLOSED Tickets'),
                  ],
                ),
              ),
            ],

            // ── Status Selection for Track Tickets ──
            if (!isUser &&
                message.type == 'status_selection' &&
                message.tempData?['action'] == 'track_tickets_by_status') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _buildStatusOptionsContainer(
                  title: 'Track Tickets by Status',
                  icon: Icons.track_changes,
                  options: [
                    _buildStatusOption('OPEN', Icons.email, Colors.blue,
                        '🔍 OPEN Tickets'),
                    _buildStatusOption('IN_PROGRESS', Icons.access_time,
                        Colors.orange, '🔍 IN_PROGRESS Tickets'),
                    _buildStatusOption('RESOLVED', Icons.check_circle,
                        Colors.green, '🔍 RESOLVED Tickets'),
                    _buildStatusOption(
                        'CLOSED', Icons.lock, Colors.grey, '🔍 CLOSED Tickets'),
                  ],
                ),
              ),
            ],
            
            // ── Ticket List (View Tickets) ──
            if (!isUser && message.isTicketList && message.tickets != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: TicketListWidget(
                  tickets: message.tickets!,
                  onTicketTap: (ticket) =>
                      onOptionSelected('🔍 View Ticket #${ticket.id}'),
                  onQuickReply: onOptionSelected,
                ),
              ),
            ],

            // ── Track Ticket List ──
            if (!isUser &&
                message.type == 'track_ticket_list' &&
                message.tickets != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _TrackTicketListWidget(
                  tickets: message.tickets!,
                  onTicketTap: (ticket) =>
                      onOptionSelected('🔍 Track #${ticket.id}'),
                  onQuickReply: onOptionSelected,
                ),
              ),
            ],

            // ── Track Ticket Detail ──
            if (!isUser &&
                message.type == 'track_ticket_detail' &&
                message.ticket != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _TrackTicketDetailCard(
                  ticket: message.ticket!,
                  onOptionSelected: onOptionSelected,
                ),
              ),
            ],

            // ── View Ticket Detail ──
            if (!isUser &&
                message.type == 'ticket_detail' &&
                message.ticket != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: TicketDetailWidget(
                  ticket: message.ticket!,
                  onQuickReply: onOptionSelected,
                ),
              ),
            ],

            // ── Ticket Confirmation ──
            if (!isUser && message.type == 'ticket_confirmation') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(message.text,
                                style: const TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                      if (message.ticketId != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number,
                                  size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Ticket ID: ${message.ticketId}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ── Update Status Options ──
            if (!isUser &&
                message.type == 'status_selection' &&
                message.tempData?['ticketId'] != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _buildUpdateStatusOptions(
                    message.tempData?['ticketId'] ?? ''),
              ),
            ],

            // ── Resolution Input ──
            if (!isUser && message.type == 'resolution_input') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _buildResolutionInput(
                    message.tempData?['ticketId'] ?? ''),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Avatar ──
  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1)
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  // ── FAQ Menu Widget ──
  Widget _buildFaqMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Frequently Asked Questions',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ..._buildFaqQuestionItems(),
          const Divider(height: 1),
          _buildFaqFooterItem('🏠 Main Menu'),
        ],
      ),
    );
  }

  List<Widget> _buildFaqQuestionItems() {
    const questions = [
      '📅 Where can I view my work schedule?',
      '👥 How can I check the staff rota?',
      '✅ How can I see my assigned tasks?',
      '📋 How can I add a new task?',
      '📌 How can I view today\'s tasks?',
      '📅 How can I check upcoming tasks?',
      '✔️ How can I see completed tasks?',
      '🔄 How can I update the status of a task?',
    ];
    
    return questions.map((question) {
      IconData? leadingIcon;
      if (question.startsWith('📅')) {
        leadingIcon = Icons.calendar_today;
      } else if (question.startsWith('👥')) {
        leadingIcon = Icons.people;
      } else if (question.startsWith('✅')) {
        leadingIcon = Icons.checklist;
      } else if (question.startsWith('📋')) {
        leadingIcon = Icons.add_task;
      } else if (question.startsWith('📌')) {
        leadingIcon = Icons.today;
      } else if (question.startsWith('✔️')) {
        leadingIcon = Icons.done_all;
      } else if (question.startsWith('🔄')) {
        leadingIcon = Icons.sync;
      } else {
        leadingIcon = Icons.help_outline;
      }
      
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOptionSelected(question),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(leadingIcon, size: 14, color: Colors.purple.shade700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.replaceFirst(RegExp(r'^[📅👥✅📋📌✔️🔄] '), ''),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFaqFooterItem(String reply) {
    return InkWell(
      onTap: () => onOptionSelected(reply),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              reply == '🏠 Main Menu' ? Icons.home : Icons.help,
              size: 14,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              reply.replaceFirst('🏠 ', ''),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqAnswerFooter(String reply) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onOptionSelected(reply),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: reply == '🏠 Main Menu' ? Colors.grey.shade100 : Colors.purple.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: reply == '🏠 Main Menu' ? Colors.grey.shade300 : Colors.purple.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reply == '🏠 Main Menu' ? Icons.home : Icons.help,
                size: 12,
                color: reply == '🏠 Main Menu' ? Colors.grey.shade700 : Colors.purple.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                reply.replaceFirst('🏠 ', '').replaceFirst('📚 ', ''),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: reply == '🏠 Main Menu' ? Colors.grey.shade700 : Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message content (text + validation error + image) ──
  Widget _buildMessageContent() {
    if (message.type == 'ticket_image' && message.imageData != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text,
              style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 13,
                  height: 1.4)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              // Handled elsewhere
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                message.imageData!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      );
    }

    if (message.validationError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text,
              style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(message.validationError!,
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Text(
      message.text,
      style: TextStyle(
          color: message.isUser ? Colors.white : Colors.black87,
          fontSize: 13,
          height: 1.4),
    );
  }

  // ── Quick reply chip ──
  Widget _buildModernOptionChip(String option) {
    Color getColor() {
      if (option.contains('Generate')) return Colors.purple;
      if (option.contains('Use')) return Colors.green;
      if (option.contains('Type')) return Colors.blue;
      if (option.contains('Cancel')) return Colors.red;
      if (option.contains('Resend')) return Colors.orange;
      if (option.contains('View')) return Colors.teal;
      if (option.contains('Create')) return Colors.indigo;
      if (option.contains('Track')) return Colors.orange;
      if (option.contains('Update')) return Colors.amber;
      if (option.contains('FAQ')) return Colors.purple;
      return Colors.grey;
    }

    final color = getColor();
    return Material(
      elevation: 1,
      shadowColor: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onOptionSelected(option),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(option,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w500, fontSize: 11)),
        ),
      ),
    );
  }

  // ── Status options container ──
  Widget _buildStatusOptionsContainer({
    required String title,
    required IconData icon,
    required List<Widget> options,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: options),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _smallActionBtn(
              icon: Icons.home,
              label: 'Main Menu',
              onTap: () => onOptionSelected('🏠 Main Menu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
      String status, IconData icon, Color color, String quickReply) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 14),
      ),
      title: Text(status,
          style: TextStyle(
              fontWeight: FontWeight.w500, color: color, fontSize: 12)),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
      onTap: () => onOptionSelected(quickReply),
    );
  }

  Widget _buildUpdateStatusOptions(String ticketId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Select New Status',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: [
              _buildUpdateStatusOption(
                  'OPEN', Icons.email, Colors.blue, ticketId),
              _buildUpdateStatusOption(
                  'IN_PROGRESS', Icons.access_time, Colors.orange, ticketId),
              _buildUpdateStatusOption(
                  'RESOLVED', Icons.check_circle, Colors.green, ticketId),
              _buildUpdateStatusOption(
                  'REOPENED', Icons.refresh, Colors.purple, ticketId),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateStatusOption(
      String status, IconData icon, Color color, String ticketId) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 14),
      ),
      title: Text(status,
          style: TextStyle(
              fontWeight: FontWeight.w500, color: color, fontSize: 12)),
      onTap: () =>
          onOptionSelected('✅ Set Status: $status for #$ticketId'),
    );
  }

  Widget _buildResolutionInput(String ticketId) {
    final controller = TextEditingController();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.note_add, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Add Resolution',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Type resolution details...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onOptionSelected('❌ Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            onOptionSelected(
                                '📝 Submit Resolution: ${controller.text}');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Submit',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Track Ticket List Widget ─────────────────────────────────────────────────
class _TrackTicketListWidget extends StatelessWidget {
  final List<TicketModel> tickets;
  final Function(TicketModel) onTicketTap;
  final Function(String) onQuickReply;

  const _TrackTicketListWidget({
    required this.tickets,
    required this.onTicketTap,
    required this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.track_changes, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Select Ticket to Track',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ...tickets.take(10).map((t) => _buildTicketItem(t)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _actionBtn(
              icon: Icons.home_outlined,
              label: 'Main Menu',
              onTap: () => onQuickReply('🏠 Main Menu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(TicketModel ticket) {
    final name = _ticketDisplayName(ticket);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTicketTap(ticket),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(
            children: [
              Container(
                  width: 3,
                  height: 35,
                  decoration: BoxDecoration(
                      color: ticket.statusColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: ticket.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(ticket.statusIcon, color: ticket.statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ticket.hasUserImage || ticket.hasResUserImage)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.attach_file,
                                size: 11, color: Colors.purple.shade300),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ticket.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(ticket.statusText,
                              style: TextStyle(
                                  fontSize: 8,
                                  color: ticket.statusColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 6),
                        Text('#${ticket.id}',
                            style: TextStyle(
                                fontSize: 8, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 10, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Track Ticket Detail Card ─────────────────────────────────────────────────
class _TrackTicketDetailCard extends StatelessWidget {
  final TicketModel ticket;
  final Function(String) onOptionSelected;

  const _TrackTicketDetailCard({
    required this.ticket,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ticketIdInt = int.tryParse(ticket.id);
    final name = _ticketDisplayName(ticket);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    ticket.statusColor,
                    ticket.statusColor.withValues(alpha: 0.8)
                  ]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(ticket.statusIcon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ticket #${ticket.id}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(ticket.statusText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
                if (ticket.hasUserImage || ticket.hasResUserImage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${(ticket.hasUserImage ? 1 : 0) + (ticket.hasResUserImage ? 1 : 0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ticket.queryType?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(Icons.category,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('Query Type',
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ticket.description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade800)),
                ),
                const SizedBox(height: 12),

                _infoRow('Created:', _fmtFull(ticket.createdAt),
                    Icons.calendar_today, Colors.blue),
                if (ticket.resolvedAt != null)
                  _infoRow('Resolved:', _fmtFull(ticket.resolvedAt!),
                      Icons.check_circle, Colors.green),
                if (ticket.closedDate != null)
                  _infoRow('Closed:', _fmtFull(ticket.closedDate!),
                      Icons.lock, Colors.grey),

                if (ticket.currentResolutionSummary?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description,
                                size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text('Resolution',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(ticket.currentResolutionSummary!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.green.shade800)),
                      ],
                    ),
                  ),
                ],

                // ── Inline attachments ──
                if (ticketIdInt != null &&
                    (ticket.hasUserImage || ticket.hasResUserImage)) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.attach_file,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text('Attachments',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (ticket.hasUserImage)
                    _InlineTicketImage(
                      ticketId: ticketIdInt,
                      fileType: 'USER',
                      label: 'User Attachment',
                    ),
                  if (ticket.hasUserImage && ticket.hasResUserImage)
                    const SizedBox(height: 10),
                  if (ticket.hasResUserImage)
                    _InlineTicketImage(
                      ticketId: ticketIdInt,
                      fileType: 'DEVELOPER',
                      label: 'Developer Attachment',
                    ),
                ],
              ],
            ),
          ),

          // ── Actions ──
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn2(
                    icon: Icons.arrow_back,
                    label: 'Back',
                    onTap: () => onOptionSelected('🔍 Track Ticket'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _actionBtn2(
                    icon: Icons.home,
                    label: 'Main Menu',
                    onTap: () => onOptionSelected('🏠 Main Menu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn2(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _fmtFull(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─── Ticket List Widget (View Tickets flow) ───────────────────────────────────
class TicketListWidget extends StatelessWidget {
  final List<TicketModel> tickets;
  final Function(TicketModel) onTicketTap;
  final Function(String) onQuickReply;

  const TicketListWidget({
    super.key,
    required this.tickets,
    required this.onTicketTap,
    required this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.confirmation_number,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Your Tickets',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${tickets.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ...tickets.take(10).map((t) => _buildTicketItem(t)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    icon: Icons.add_circle_outline,
                    label: 'Create New',
                    onTap: () => onQuickReply('🎫 Create Ticket'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    icon: Icons.home_outlined,
                    label: 'Main Menu',
                    onTap: () => onQuickReply('🏠 Main Menu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(TicketModel ticket) {
    final name = _ticketDisplayName(ticket);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTicketTap(ticket),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(
            children: [
              Container(
                  width: 3,
                  height: 35,
                  decoration: BoxDecoration(
                      color: ticket.statusColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: ticket.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(ticket.statusIcon,
                    color: ticket.statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (ticket.hasUserImage || ticket.hasResUserImage)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.attach_file,
                                size: 11, color: Colors.purple.shade300),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.description.length > 30
                          ? '${ticket.description.substring(0, 30)}…'
                          : ticket.description,
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ticket.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(ticket.statusText,
                              style: TextStyle(
                                  fontSize: 8,
                                  color: ticket.statusColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 6),
                        Text(_fmt(ticket.createdAt),
                            style: TextStyle(
                                fontSize: 8, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 10, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─── Ticket Detail Widget (View Ticket flow) ──────────────────────────────────
class TicketDetailWidget extends StatelessWidget {
  final TicketModel ticket;
  final Function(String) onQuickReply;

  const TicketDetailWidget({
    super.key,
    required this.ticket,
    required this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    final ticketIdInt = int.tryParse(ticket.id);
    final name = _ticketDisplayName(ticket);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    ticket.statusColor,
                    ticket.statusColor.withValues(alpha: 0.8)
                  ]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(ticket.statusIcon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ticket #${ticket.id}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(ticket.statusText,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
                if (ticket.hasUserImage || ticket.hasResUserImage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${(ticket.hasUserImage ? 1 : 0) + (ticket.hasResUserImage ? 1 : 0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ticket.queryType?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(Icons.category,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('Query Type',
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ticket.description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade800)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(ticket.createdBy,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(_fmt(ticket.createdAt),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),

                // ── Inline attachments ──
                if (ticketIdInt != null &&
                    (ticket.hasUserImage || ticket.hasResUserImage)) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.attach_file,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text('Attachments',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (ticket.hasUserImage)
                    _InlineTicketImage(
                      ticketId: ticketIdInt,
                      fileType: 'USER',
                      label: 'User Attachment',
                    ),
                  if (ticket.hasUserImage && ticket.hasResUserImage)
                    const SizedBox(height: 10),
                  if (ticket.hasResUserImage)
                    _InlineTicketImage(
                      ticketId: ticketIdInt,
                      fileType: 'DEVELOPER',
                      label: 'Developer Attachment',
                    ),
                ],
              ],
            ),
          ),

          // ── Quick Actions ──
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    icon: Icons.arrow_back,
                    label: 'Back',
                    onTap: () => onQuickReply('📋 View My Tickets'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    icon: Icons.home,
                    label: 'Main Menu',
                    onTap: () => onQuickReply('🏠 Main Menu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _actionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Modern Ticket Form ───────────────────────────────────────────────────────
// ─── Modern Ticket Form with Module Selection ─────────────────────────────────
class _ModernTicketForm extends StatefulWidget {
  final Function(String, String, String, String, List<File>) onSubmit;
  final VoidCallback onCancel;

  const _ModernTicketForm({required this.onSubmit, required this.onCancel});

  @override
  State<_ModernTicketForm> createState() => _ModernTicketFormState();
}

class _ModernTicketFormState extends State<_ModernTicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final TextEditingController _moduleSearchController = TextEditingController();

  String? _selectedQueryType;
  String? _selectedModule;
  String _selectedPriority = 'MEDIUM';
  List<File> _selectedImages = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  bool _isLoadingModules = false;
  
  List<Map<String, dynamic>> _modulesList = [];
  List<Map<String, dynamic>> _filteredModulesList = [];
  bool _showModulePicker = false;

  // ── Query type → icon mapping ──
  static const List<Map<String, dynamic>> _queryItems = [
    {'label': 'Access Request',       'icon': Icons.vpn_key_rounded},
    {'label': 'Billing Issue',        'icon': Icons.credit_card_rounded},
    {'label': 'Data Correction Issue','icon': Icons.storage_rounded},
    {'label': 'Feature Request',      'icon': Icons.auto_awesome_rounded},
    {'label': 'General Query',        'icon': Icons.chat_bubble_outline_rounded},
    {'label': 'Network Issue',        'icon': Icons.wifi_rounded},
    {'label': 'Password Request',     'icon': Icons.lock_reset_rounded},
    {'label': 'Software Issue',       'icon': Icons.computer_rounded},
    {'label': 'Other',                'icon': Icons.list_alt_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadModules();
  }
  
  @override
  void dispose() {
    _moduleSearchController.dispose();
    super.dispose();
  }

// Update the _loadModules method in _ModernTicketFormState to handle pagination:

Future<void> _loadModules() async {
  setState(() {
    _isLoadingModules = true;
  });
  
  try {
    List<Map<String, dynamic>> allModules = [];
    int currentPage = 0;
    bool hasMore = true;
    
    while (hasMore) {
      final result = await SupportService.getModulesList(
        page: currentPage,
        size: 50, // Fetch up to 50 per request
      );
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        
        // Parse the response - adjust based on your API response structure
        List<Map<String, dynamic>> modules = [];
        
        // Check for paginated response structure
        if (data['data'] != null && data['data'] is List) {
          modules = List<Map<String, dynamic>>.from(data['data']);
          // Check if there are more pages
          final totalPages = data['totalPages'] ?? data['total_pages'];
          final totalElements = data['totalElements'] ?? data['total_elements'];
          if (totalPages != null) {
            hasMore = currentPage + 1 < totalPages;
          } else if (totalElements != null) {
            hasMore = allModules.length + modules.length < totalElements;
          } else {
            hasMore = modules.length == 50; // If we got full page, assume more
          }
        } else if (data is List) {
          modules = List<Map<String, dynamic>>.from(data);
          hasMore = false; // If it's a direct list, assume all data is returned
        } else if (data is Map && data['modules'] != null && data['modules'] is List) {
          modules = List<Map<String, dynamic>>.from(data['modules']);
          hasMore = false;
        } else if (data is Map && data['list'] != null && data['list'] is List) {
          modules = List<Map<String, dynamic>>.from(data['list']);
          hasMore = false;
        } else {
          hasMore = false;
        }
        
        // Format modules with consistent structure
        final formattedModules = modules.map((module) {
          return {
            'id': module['id'] ?? module['moduleId'] ?? module['code'] ?? '',
            'name': module['name'] ?? module['moduleName'] ?? module['title'] ?? 'Unknown',
            'description': module['description'] ?? '',
            'icon': _getModuleIcon(module['name'] ?? module['moduleName'] ?? ''),
          };
        }).toList();
        
        allModules.addAll(formattedModules);
        currentPage++;
        
        debugPrint('📋 Fetched page $currentPage: ${modules.length} modules, total so far: ${allModules.length}');
      } else {
        hasMore = false;
      }
    }
    
    _modulesList = allModules;
    _filteredModulesList = List.from(_modulesList);
    
    debugPrint('✅ Loaded total ${_modulesList.length} modules');
    
  } catch (e) {
    debugPrint('❌ Error loading modules: $e');
    _modulesList = [];
    _filteredModulesList = [];
  } finally {
    setState(() {
      _isLoadingModules = false;
    });
  }
}
  
  IconData _getModuleIcon(String moduleName) {
    final name = moduleName.toLowerCase();
    if (name.contains('patient')) return Icons.person;
    if (name.contains('appointment')) return Icons.calendar_today;
    if (name.contains('billing') || name.contains('invoice')) return Icons.receipt;
    if (name.contains('pharmacy') || name.contains('medicine')) return Icons.local_pharmacy;
    if (name.contains('lab') || name.contains('test')) return Icons.science;
    if (name.contains('radiology') || name.contains('xray')) return Icons.image;
    if (name.contains('operation') || name.contains('surgery')) return Icons.local_hospital;
    if (name.contains('ward') || name.contains('bed')) return Icons.hotel;
    if (name.contains('staff') || name.contains('employee')) return Icons.people;
    if (name.contains('report')) return Icons.analytics;
    if (name.contains('inventory') || name.contains('stock')) return Icons.inventory;
    if (name.contains('dashboard')) return Icons.dashboard;
    if (name.contains('settings')) return Icons.settings;
    return Icons.apps;
  }
  
  void _filterModules(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredModulesList = List.from(_modulesList);
      } else {
        _filteredModulesList = _modulesList.where((module) {
          final name = module['name'].toString().toLowerCase();
          final description = module['description'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || description.contains(searchQuery);
        }).toList();
      }
    });
  }

  // ── Show query type bottom sheet ──
  void _showQueryTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Sheet title
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'CHOOSE CATEGORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // 3-column icon grid
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  children: _queryItems.map((item) {
                    final label = item['label'] as String;
                    final icon  = item['icon']  as IconData;
                    final isSelected = _selectedQueryType == label;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedQueryType = label);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8EAF6)
                              : const Color(0xFFFAFBFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1A237E)
                                : const Color(0xFFE8EAF6),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 22,
                              color: isSelected
                                  ? const Color(0xFF1A237E)
                                  : const Color(0xFF5C6BC0),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF1A237E)
                                    : const Color(0xFF3949AB),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ── Show module selection bottom sheet with search ──
 // Enhanced module selection sheet with infinite scrolling
void _showModuleSelectionSheet() {
  _moduleSearchController.clear();
  _filterModules('');
  
  // For infinite scrolling, we'll keep track of loaded modules separately
  List<Map<String, dynamic>> displayedModules = [];
  int _currentPage = 0;
  bool _hasMoreModules = true;
  bool _isLoadingMore = false;
  
  // Load first batch
  displayedModules = List.from(_modulesList);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        // Function to load more modules
        Future<void> loadMoreModules() async {
          if (_isLoadingMore || !_hasMoreModules) return;
          
          setSheetState(() {
            _isLoadingMore = true;
          });
          
          try {
            final result = await SupportService.getModulesList(
              page: _currentPage,
              size: 50,
            );
            
            if (result['success'] == true && result['data'] != null) {
              final data = result['data'];
              List<Map<String, dynamic>> newModules = [];
              
              if (data['data'] != null && data['data'] is List) {
                newModules = List<Map<String, dynamic>>.from(data['data']);
                final totalPages = data['totalPages'] ?? data['total_pages'];
                if (totalPages != null) {
                  _hasMoreModules = _currentPage + 1 < totalPages;
                } else {
                  _hasMoreModules = newModules.length == 50;
                }
              } else if (data is List) {
                newModules = List<Map<String, dynamic>>.from(data);
                _hasMoreModules = false;
              }
              
              final formattedModules = newModules.map((module) {
                return {
                  'id': module['id'] ?? module['moduleId'] ?? module['code'] ?? '',
                  'name': module['name'] ?? module['moduleName'] ?? module['title'] ?? 'Unknown',
                  'description': module['description'] ?? '',
                  'icon': _getModuleIcon(module['name'] ?? module['moduleName'] ?? ''),
                };
              }).toList();
              
              setSheetState(() {
                displayedModules.addAll(formattedModules);
                _currentPage++;
              });
            } else {
              _hasMoreModules = false;
            }
          } catch (e) {
            debugPrint('Error loading more modules: $e');
            _hasMoreModules = false;
          } finally {
            setSheetState(() {
              _isLoadingMore = false;
            });
          }
        }
        
        // Scroll controller for infinite scroll
        final scrollController = ScrollController();
        scrollController.addListener(() {
          if (scrollController.position.pixels >= 
              scrollController.position.maxScrollExtent - 200) {
            if (!_isLoadingMore && _hasMoreModules && _moduleSearchController.text.isEmpty) {
              loadMoreModules();
            }
          }
        });
        
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title with count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.apps, size: 18, color: Color(0xFF1A237E)),
                    const SizedBox(width: 8),
                    Text(
                      'SELECT MODULE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A237E),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_modulesList.length} Available',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _moduleSearchController,
                    onChanged: (value) {
                      setSheetState(() {
                        _filterModules(value);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search ${_modulesList.length} modules...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              
              // Loading indicator for initial load
              if (_isLoadingModules)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading modules...'),
                      ],
                    ),
                  ),
                ),
              
              // Empty state
              if (!_isLoadingModules && _filteredModulesList.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _modulesList.isEmpty ? 'No modules available' : 'No matching modules',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (_modulesList.isEmpty)
                          TextButton(
                            onPressed: _loadModules,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ),
              
              // Modules List with infinite scroll
              if (!_isLoadingModules && _filteredModulesList.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredModulesList.length + (_hasMoreModules && _moduleSearchController.text.isEmpty ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      if (index == _filteredModulesList.length) {
                        // Loading more indicator
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Loading more modules...',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      final module = _filteredModulesList[index];
                      final isSelected = _selectedModule == module['name'];
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedModule = module['name'];
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE8EAF6)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1A237E)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1A237E).withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  module['icon'] as IconData,
                                  color: isSelected
                                      ? const Color(0xFF1A237E)
                                      : const Color(0xFF5C6BC0),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module['name'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF1A237E)
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    if (module['description'] != null && module['description'].toString().isNotEmpty)
                                      Text(
                                        module['description'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    size: 18, color: const Color(0xFF1A237E)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF283593)]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Create Support Ticket',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // ── Query Type ──
                    FormField<String>(
                      validator: (_) => (_selectedQueryType == null || _selectedQueryType!.isEmpty)
                          ? 'Please select a query type'
                          : null,
                      builder: (fieldState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _showQueryTypeSheet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _selectedQueryType != null
                                    ? const Color(0xFFE8EAF6)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: fieldState.hasError
                                      ? Colors.red.shade400
                                      : _selectedQueryType != null
                                          ? const Color(0xFF3949AB)
                                          : Colors.grey.shade200,
                                  width: _selectedQueryType != null ? 1.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedQueryType != null
                                        ? _queryItems.firstWhere(
                                            (e) => e['label'] == _selectedQueryType,
                                            orElse: () => _queryItems.last,
                                          )['icon'] as IconData
                                        : Icons.category_outlined,
                                    size: 16,
                                    color: _selectedQueryType != null
                                        ? const Color(0xFF1A237E)
                                        : Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedQueryType ?? 'Select Query Type',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedQueryType != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _selectedQueryType != null
                                            ? const Color(0xFF1A237E)
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  if (_selectedQueryType != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A237E),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.check,
                                          size: 10, color: Colors.white),
                                    )
                                  else
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                          if (fieldState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                fieldState.errorText!,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.red.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // ── Module Selection (NEW) ──
                    FormField<String>(
                      validator: (_) => (_selectedModule == null || _selectedModule!.isEmpty)
                          ? 'Please select a module'
                          : null,
                      builder: (fieldState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _isLoadingModules ? null : _showModuleSelectionSheet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _selectedModule != null
                                    ? const Color(0xFFE8EAF6)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: fieldState.hasError
                                      ? Colors.red.shade400
                                      : _selectedModule != null
                                          ? const Color(0xFF3949AB)
                                          : Colors.grey.shade200,
                                  width: _selectedModule != null ? 1.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  if (_isLoadingModules)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 1.5),
                                    )
                                  else
                                    Icon(
                                      _selectedModule != null
                                          ? (_modulesList.firstWhere(
                                              (e) => e['name'] == _selectedModule,
                                              orElse: () => {'icon': Icons.apps},
                                            )['icon'] as IconData)
                                          : Icons.apps,
                                      size: 16,
                                      color: _selectedModule != null
                                          ? const Color(0xFF1A237E)
                                          : Colors.grey.shade500,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedModule ?? (_isLoadingModules ? 'Loading modules...' : 'Select Module'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedModule != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _selectedModule != null
                                            ? const Color(0xFF1A237E)
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  if (_selectedModule != null && !_isLoadingModules)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A237E),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.check,
                                          size: 10, color: Colors.white),
                                    )
                                  else if (!_isLoadingModules)
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                          if (fieldState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                fieldState.errorText!,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.red.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Description ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Description',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          prefixIcon: Icon(Icons.description,
                              color: Colors.grey.shade600, size: 16),
                        ),
                        style: const TextStyle(fontSize: 12),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Image Upload ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.image,
                                  size: 14, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text('Attachments (Optional)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_selectedImages.isNotEmpty) ...[
                            SizedBox(
                              height: 44,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, i) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          image: DecorationImage(
                                            image:
                                                FileImage(_selectedImages[i]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => setState(() =>
                                              _selectedImages.removeAt(i)),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle),
                                            child: const Icon(Icons.close,
                                                size: 8, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          InkWell(
                            onTap: _isUploading ? null : _pickImages,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isUploading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.blue)),
                                    )
                                  else
                                    Icon(Icons.cloud_upload,
                                        size: 12,
                                        color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isUploading
                                        ? 'Uploading…'
                                        : 'Upload Images',
                                    style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Max 1 MB • JPG, PNG',
                              style: TextStyle(
                                  fontSize: 8, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Buttons ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isSubmitting ? null : widget.onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white))
                                : const Text('Create',
                                    style: TextStyle(fontSize: 11)),
                          ),
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
    );
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
            .where((f) => f.size <= 1048576)
            .map((f) => File(f.path!))
            .toList();
        setState(() => _selectedImages.addAll(valid));
      }
    } catch (_) {}
    setState(() => _isUploading = false);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _selectedQueryType!,
      _selectedModule!,
      _descriptionController.text,
      _selectedPriority,
      _selectedImages,
    );
    if (mounted) setState(() => _isSubmitting = false);
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class _ModernTypingIndicator extends StatelessWidget {
  const _ModernTypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration:
                const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            child:
                const Icon(Icons.support_agent, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeInOut,
      builder: (context, double v, child) {
        return Container(
          width: 6 * v,
          height: 6 * v,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.grey.shade500),
        );
      },
    );
  }
}