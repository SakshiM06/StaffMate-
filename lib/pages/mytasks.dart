import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/services/my_tasks_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── THEME CONSTANTS ──────────────────────────────────────────────────────────
class _AppColors {
  static const primary = Color(0xFF1A1A2E);
  static const accent = Color(0xFF4F46E5);
  static const accentLight = Color(0xFFEEF2FF);
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEE2E2);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const cardShadow = Color(0x0A000000);
  static const starColor = Color(0xFFFBBF24);
}

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  String? _selectedTaskCategory;
  String? _selectedSubCategory;
  final List<Task> _tasks = [];
  List<MasterCategory> _masterCategories = [];
  bool _isLoadingTasks = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isSideMenuOpen = false;
  DateTime _selectedCalendarDate = DateTime.now();
  List<Task> _calendarTasks = [];
  bool _isLoadingCalendarTasks = false;
  
  // Starred tasks
  Set<int> _starredTaskIds = {};
  List<Task> _starredTasks = [];

  final Map<String, List<Task>> _tasksByStatus = {
    'TODAY': [],
    'UPCOMING': [],
    'COMPLETED': [],
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMasterCategories();
    _loadAllTasks();
    _loadStarredTasks();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReminders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── STARRED TASKS ─────────────────────────────────────────────────────────
  Future<void> _loadStarredTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final starredJson = prefs.getString('starred_tasks');
    if (starredJson != null) {
      final List<dynamic> decoded = jsonDecode(starredJson);
      _starredTaskIds = decoded.map((e) => e as int).toSet();
    }
    _updateStarredTasksList();
  }

  Future<void> _saveStarredTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('starred_tasks', jsonEncode(_starredTaskIds.toList()));
    _updateStarredTasksList();
  }

  void _updateStarredTasksList() {
    final List<Task> allTasks = [
      ...?_tasksByStatus['TODAY'],
      ...?_tasksByStatus['UPCOMING'],
      ...?_tasksByStatus['COMPLETED'],
    ];
    _starredTasks = allTasks.where((t) => t.realId != null && _starredTaskIds.contains(t.realId)).toList();
    if (mounted) setState(() {});
  }

  void _toggleStarred(Task task) {
    if (task.realId == null) return;
    setState(() {
      if (_starredTaskIds.contains(task.realId)) {
        _starredTaskIds.remove(task.realId);
      } else {
        _starredTaskIds.add(task.realId!);
      }
    });
    _saveStarredTasks();
  }

  bool _isStarred(Task task) => task.realId != null && _starredTaskIds.contains(task.realId);

  // ─── DATA LOADING ─────────────────────────────────────────────────────────

  Future<void> _loadAllTasks() async {
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);
    try {
      await Future.wait([
        _fetchTasksByStatus('TODAY'),
        _fetchTasksByStatus('UPCOMING'),
        _fetchTasksByStatus('COMPLETED'),
      ]);
      _mergeAllTasks();
      _updateStarredTasksList();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) _showSnackBar('Failed to load tasks', _AppColors.danger);
    } finally {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _fetchTasksByStatus(String status) async {
    try {
      final cachedData = await MyTasksService.getCachedTasksByStatus(status);
      if (cachedData != null && mounted) {
        _processTasksResponse(cachedData, status);
        return;
      }
      final response = await MyTasksService.fetchTasksByStatus(status);
      if (mounted) _processTasksResponse(response, status);
    } catch (e) {
      debugPrint('Error fetching tasks for status $status: $e');
      if (mounted) setState(() => _tasksByStatus[status] = []);
    }
  }

  void _processTasksResponse(Map<String, dynamic> response, String status) {
    List<dynamic> tasksData = [];
    if (response.containsKey('data')) {
      final dataObj = response['data'];
      if (dataObj is List) {
        tasksData = dataObj;
      } else if (dataObj is Map<String, dynamic>) {
        if (dataObj.containsKey('list') && dataObj['list'] is List) {
          tasksData = dataObj['list'] as List;
        } else if (dataObj.containsKey('content') && dataObj['content'] is List) {
          tasksData = dataObj['content'] as List;
        }
      }
    } else if (response.containsKey('list') && response['list'] is List) {
      tasksData = response['list'] as List;
    }

    if (mounted) {
      setState(() {
        final List<Task> tasks = [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        for (var item in tasksData) {
          if (item is Map<String, dynamic>) {
            try {
              Task task = Task.fromJson(item, status);
              
              if (task.dueDate.isBefore(now) && !task.isCompleted) {
                task.status = 'overdue';
              } else if (task.alertDate != null && 
                         task.alertDate!.isBefore(now) && 
                         task.alertDate!.isAfter(now.subtract(const Duration(days: 1))) &&
                         !task.isCompleted) {
                task.status = 'due_soon';
              } else if (task.dueDate.year == today.year &&
                         task.dueDate.month == today.month &&
                         task.dueDate.day == today.day) {
                task.status = 'today';
              } else if (task.dueDate.isAfter(now)) {
                task.status = 'upcoming';
              } else if (task.isCompleted) {
                task.status = 'completed';
              }
              
              tasks.add(task);
            } catch (e) {
              debugPrint('Error parsing task: $e');
            }
          }
        }
        _tasksByStatus[status] = tasks;
      });
    }
  }

  void _mergeAllTasks() {
    final allTasks = <Task>[];
    _tasksByStatus.forEach((status, tasks) => allTasks.addAll(tasks));
    if (mounted) {
      setState(() {
        _tasks.clear();
        _tasks.addAll(allTasks);
      });
    }
  }

  Future<void> _loadMasterCategories() async {
    if (!mounted) return;
    try {
      final cachedData = await MyTasksService.getCachedMasterCategories();
      if (cachedData != null && mounted) {
        _processCategoriesResponse(cachedData);
        return;
      }
      final response = await MyTasksService.getMasterCategories();
      if (mounted) _processCategoriesResponse(response);
    } catch (e) {
      debugPrint('Error loading master categories: $e');
      if (mounted) setState(() => _masterCategories = []);
    }
  }

  void _processCategoriesResponse(Map<String, dynamic> response) {
    List<dynamic> categoriesData = [];
    if (response.containsKey('data')) {
      final dataObj = response['data'];
      if (dataObj is List) {
        categoriesData = dataObj;
      } else if (dataObj is Map<String, dynamic>) {
        if (dataObj.containsKey('list') && dataObj['list'] is List) {
          categoriesData = dataObj['list'] as List;
        }
      }
    }
    if (mounted) {
      setState(() {
        _masterCategories = categoriesData.map((item) {
          if (item is Map<String, dynamic>) return MasterCategory.fromJson(item);
          return MasterCategory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: item.toString(),
            isActive: true,
            subCategories: const [],
          );
        }).toList();
        _masterCategories.sort((a, b) => a.name.compareTo(b.name));
      });
    }
  }

  Future<void> _refreshTasks() async {
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);
    try {
      await MyTasksService.clearTasksCache();
      await MyTasksService.clearMasterCategoriesCache();
      await MyTasksService.clearSubCategoriesCache();
      await Future.wait([
        _loadMasterCategories(),
        _loadAllTasks(),
      ]);
      await _loadTasksForDate(_selectedCalendarDate);
      if (mounted) {
        _showSnackBar('Tasks refreshed successfully', _AppColors.success);
      }
    } catch (e) {
      debugPrint('Error refreshing tasks: $e');
      if (mounted) {
        _showSnackBar('Error refreshing tasks: $e', _AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  // ─── REMINDER SCHEDULING ─────────────────────────────────────────────────

  Future<void> _scheduleReminders() async {
    final allTasks = [..._tasksByStatus['TODAY'] ?? [], ..._tasksByStatus['UPCOMING'] ?? []];
    final now = DateTime.now();
    
    for (var task in allTasks) {
      if (task.alertDate != null && !task.isCompleted) {
        final reminderTime = task.alertDate!;
        final timeUntilReminder = reminderTime.difference(now);
        
        if (timeUntilReminder.inMinutes > 0) {
          await _scheduleNotification(
            taskId: task.realId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Reminder: ${task.title}',
            body: task.description.isNotEmpty ? task.description : 'Task due ${_formatDueDate(task.dueDate)}',
            scheduledTime: reminderTime,
          );
        }
      }
    }
  }

  Future<void> _scheduleNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    debugPrint('Scheduled reminder for "$title" at $scheduledTime');
  }

  // ─── CALENDAR TASKS ───────────────────────────────────────────────────────

  Future<void> _loadTasksForDate(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCalendarTasks = true;
      _calendarTasks = [];
    });

    try {
      final allTasks = [
        ...(_tasksByStatus['TODAY'] ?? []),
        ...(_tasksByStatus['UPCOMING'] ?? []),
        ...(_tasksByStatus['COMPLETED'] ?? []),
      ];

      final tasksOnDate = allTasks.where((task) =>
          task.dueDate.year == date.year &&
          task.dueDate.month == date.month &&
          task.dueDate.day == date.day).toList();

      final List<Task> historyTasks = [];
      final formattedDate = DateFormat('dd-MM-yyyy').format(date);

      for (var task in allTasks) {
        if (task.realId != null) {
          try {
            final historyResponse = await MyTasksService.getTaskHistory(
              taskId: task.realId!,
              date: formattedDate,
            );

            final data = historyResponse['data'];
            List<dynamic>? list;
            if (data is Map<String, dynamic> && data['list'] is List) {
              list = data['list'] as List;
            } else if (data is List) {
              list = data;
            }

            if (list != null) {
              for (var historyItem in list) {
                if (historyItem is Map<String, dynamic>) {
                  try {
                    final historyTask = Task.fromJson(historyItem, 'COMPLETED');
                    if (!historyTasks.any((t) =>
                        t.realId == historyTask.realId &&
                        t.dueDate.day == historyTask.dueDate.day)) {
                      historyTasks.add(historyTask);
                    }
                  } catch (e) {
                    debugPrint('Error parsing history task: $e');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('History fetch error for task ${task.realId}: $e');
          }
        }
      }

      final merged = [...tasksOnDate];
      for (var ht in historyTasks) {
        if (!merged.any((t) => t.realId == ht.realId)) {
          merged.add(ht);
        }
      }
      merged.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      if (mounted) {
        setState(() {
          _calendarTasks = merged.cast<Task>();
          _isLoadingCalendarTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks for date: $e');
      if (mounted) {
        setState(() => _isLoadingCalendarTasks = false);
        _showSnackBar('Error loading tasks for selected date', _AppColors.danger);
      }
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Task> _getUrgentTasks() {
    final todayTasks = _tasksByStatus['TODAY'] ?? [];
    final upcomingTasks = _tasksByStatus['UPCOMING'] ?? [];
    final now = DateTime.now();
    
    final tasksWithReminders = upcomingTasks.where((t) => 
      !t.isCompleted && 
      t.alertDate != null && 
      t.alertDate!.isAfter(now) && 
      t.alertDate!.isBefore(now.add(const Duration(hours: 24)))
    ).toList();
    
    final overdueTasks = upcomingTasks.where((t) => 
      !t.isCompleted && 
      t.dueDate.isBefore(now)
    ).toList();
    
    final urgent = [...todayTasks, ...overdueTasks, ...tasksWithReminders];
    
    return urgent.toSet().toList();
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high: return _AppColors.danger;
      case Priority.medium: return _AppColors.warning;
      case Priority.low: return _AppColors.success;
    }
  }

  IconData _getPriorityIcon(Priority priority) {
    switch (priority) {
      case Priority.high: return Icons.keyboard_double_arrow_up_rounded;
      case Priority.medium: return Icons.remove_rounded;
      case Priority.low: return Icons.keyboard_double_arrow_down_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    final hash = category.hashCode;
    final hue = hash.abs() % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.55, 0.48).toColor();
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM dd').format(dueDate);
  }

  String _getRepeatPatternText(RepeatPattern pattern) {
    switch (pattern) {
      case RepeatPattern.never: return '';
      case RepeatPattern.daily: return 'Daily';
      case RepeatPattern.weekly: return 'Weekly';
      case RepeatPattern.monthly: return 'Monthly';
      case RepeatPattern.halfYearly: return 'Half-Yearly';
      case RepeatPattern.quarterly: return 'Quarterly';
      case RepeatPattern.yearly: return 'Yearly';
      case RepeatPattern.custom: return 'Custom';
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final urgentTasks = _getUrgentTasks();
    const menuWidth = 272.0;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(urgentTasks),
              Expanded(
                child: _buildCalendarView(),
              ),
            ],
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: _isSideMenuOpen ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_isSideMenuOpen,
              child: GestureDetector(
                onTap: () => setState(() => _isSideMenuOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.40),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            left: _isSideMenuOpen ? 0 : -menuWidth,
            top: 0,
            bottom: 0,
            width: menuWidth,
            child: _buildSideMenu(urgentTasks),
          ),
          Positioned(
            bottom: 28,
            right: 24,
            child: _buildFAB(),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader(List<Task> urgentTasks) {
    return Container(
      decoration: const BoxDecoration(color: _AppColors.primary),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _headerIconButton(
                    icon: _isSideMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
                    onTap: () => setState(() {
                      _isSideMenuOpen = !_isSideMenuOpen;
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Tasks',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _headerIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: _refreshTasks,
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _headerIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () => _showUrgentTasksDialog(urgentTasks),
                      ),
                      if (urgentTasks.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: _AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '${urgentTasks.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 12),
            _buildFilterAndSearchBar(),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatsRow() {
    final todayCount = _tasksByStatus['TODAY']?.length ?? 0;
    final completedCount = _tasksByStatus['COMPLETED']?.length ?? 0;
    final total = todayCount + completedCount + (_tasksByStatus['UPCOMING']?.length ?? 0);
    final completion = total == 0 ? 0.0 : completedCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getGreeting()}! 👋',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount of $total done',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(_AppColors.success),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statPill(label: 'Today', count: todayCount, color: _AppColors.accent),
          const SizedBox(width: 6),
          _statPill(label: 'Done', count: completedCount, color: _AppColors.success),
        ],
      ),
    );
  }

  Widget _statPill({required String label, required int count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
        ],
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildFilterAndSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _showCategoryFilterDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 16,
                        color: _selectedTaskCategory != null
                            ? _AppColors.accentLight
                            : Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedTaskCategory ?? 'All Categories',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedTaskCategory != null
                              ? _AppColors.accentLight
                              : Colors.white.withOpacity(0.7),
                          fontWeight: _selectedTaskCategory != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedTaskCategory != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedTaskCategory = null;
                          _selectedSubCategory = null;
                        }),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.white.withOpacity(0.7)),
                      )
                    else
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: Colors.white.withOpacity(0.7)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.7), size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add_category') {
                _showAddCategoryDialog();
              } else if (value == 'add_subcategory') {
                if (_selectedTaskCategory == null) {
                  _showSnackBar('Please select a category first from filter', _AppColors.warning);
                  return;
                }
                if (_masterCategories.isEmpty) {
                  _showSnackBar('No category data available, please reload', _AppColors.warning);
                  return;
                }
                final selectedCategory = _masterCategories.firstWhere(
                  (cat) => cat.name == _selectedTaskCategory,
                  orElse: () => _masterCategories.first,
                );
                _showAddSubCategoryForCategoryDialog(selectedCategory);
              }
            },
            offset: const Offset(0, 45),
            color: _AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _AppColors.border.withOpacity(0.5)),
            ),
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_category',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: _AppColors.accent),
                    SizedBox(width: 12),
                    Text('Add Category', style: TextStyle(color: _AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_subcategory',
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: _AppColors.accent),
                    SizedBox(width: 12),
                    Text('Add Subcategory', style: TextStyle(color: _AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SIDE MENU ────────────────────────────────────────────────────────────

  Widget _buildSideMenu(List<Task> urgentTasks) {
    return Material(
      elevation: 16,
      child: Container(
        color: _AppColors.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(30, 50, 60, 30),
              color: _AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text('Task Manager',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Stay organised',
                      style: TextStyle(fontSize: 22, color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _sideItem(icon: Icons.today_rounded, label: "Today's Tasks",
                      count: _tasksByStatus['TODAY']?.length ?? 0,
                      color: _AppColors.accent, onTap: () => _showTasksByStatus('TODAY')),
                  _sideItem(icon: Icons.upcoming_rounded, label: 'Upcoming',
                      count: _tasksByStatus['UPCOMING']?.length ?? 0,
                      color: _AppColors.warning, onTap: () => _showTasksByStatus('UPCOMING')),
                  _sideItem(icon: Icons.check_circle_outline_rounded, label: 'Completed',
                      count: _tasksByStatus['COMPLETED']?.length ?? 0,
                      color: _AppColors.success, onTap: () => _showTasksByStatus('COMPLETED')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: _AppColors.border),
                  ),
                  _sideItem(icon: Icons.star_rounded, label: 'Starred',
                      count: _starredTasks.length,
                      color: _AppColors.starColor, onTap: _showStarredTasks),
                  if (urgentTasks.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(color: _AppColors.border),
                    ),
                    _sideItemAction(
                      icon: Icons.warning_amber_rounded,
                      label: 'Urgent Tasks',
                      color: _AppColors.danger,
                      onTap: () {
                        setState(() => _isSideMenuOpen = false);
                        _showUrgentTasksDialog(urgentTasks);
                      },
                      badge: urgentTasks.length,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTasksByStatus(String status) {
    setState(() {
      _isSideMenuOpen = false;
    });
    
    final tasks = _tasksByStatus[status] ?? [];
    final String title = status == 'TODAY' ? "Today's Tasks" : (status == 'UPCOMING' ? 'Upcoming Tasks' : 'Completed Tasks');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: BoxDecoration(
                  color: status == 'TODAY' ? _AppColors.accent : (status == 'UPCOMING' ? _AppColors.warning : _AppColors.success),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'TODAY' ? Icons.today_rounded : (status == 'UPCOMING' ? Icons.upcoming_rounded : Icons.check_circle_rounded),
                      color: Colors.white, size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 48, color: _AppColors.textTertiary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text('No $title', style: const TextStyle(color: _AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (_, i) => _buildTaskCard(tasks[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStarredTasks() {
    setState(() {
      _isSideMenuOpen = false;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: const BoxDecoration(
                  color: _AppColors.starColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Starred Tasks',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _starredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_outline_rounded, size: 48, color: _AppColors.textTertiary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('No Starred Tasks', style: TextStyle(color: _AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            const Text('Tap the star icon on any task to add it here',
                                style: TextStyle(fontSize: 12, color: _AppColors.textTertiary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _starredTasks.length,
                        itemBuilder: (_, i) => _buildTaskCard(_starredTasks[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _AppColors.textPrimary,
                  )),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sideItemAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : _AppColors.textPrimary,
                  )),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text('$badge',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── CALENDAR VIEW ─────────────────────────────────────────────────────────

  Widget _buildCalendarView() {
    // Filter calendar tasks based on search query
// AFTER (with fix)
List<Task> filteredCalendarTasks;
if (_searchQuery.isNotEmpty) {
  final q = _searchQuery.toLowerCase();
  // Search across ALL tasks regardless of selected date/status
  final allTasks = <Task>[
    ...(_tasksByStatus['TODAY'] ?? []),
    ...(_tasksByStatus['UPCOMING'] ?? []),
    ...(_tasksByStatus['COMPLETED'] ?? []),
  ];
  filteredCalendarTasks = allTasks.where((task) =>
      task.title.toLowerCase().contains(q) ||
      task.description.toLowerCase().contains(q)).toList();
} else {
  filteredCalendarTasks = _calendarTasks;
}
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: _AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _AppColors.cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCalendarHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildWeekdayHeaders(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _buildCalendarGrid(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_note_rounded,
                      size: 16, color: _AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM dd').format(_selectedCalendarDate),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _AppColors.textPrimary),
                  ),
                ),
                if (filteredCalendarTasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filteredCalendarTasks.length} task${filteredCalendarTasks.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _AppColors.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1, color: _AppColors.border)),
        if (_isLoadingCalendarTasks)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: _AppColors.accent)),
          )
        else if (filteredCalendarTasks.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 36, color: _AppColors.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text(_searchQuery.isNotEmpty ? 'No matching tasks for this date' : 'No tasks for this date',
                      style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildTaskCard(filteredCalendarTasks[i]),
                childCount: filteredCalendarTasks.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedCalendarDate = DateTime(
                  _selectedCalendarDate.year,
                  _selectedCalendarDate.month - 1,
                );
              });
              _loadTasksForDate(_selectedCalendarDate);
            },
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedCalendarDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _AppColors.textPrimary),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedCalendarDate = DateTime(
                  _selectedCalendarDate.year,
                  _selectedCalendarDate.month + 1,
                );
              });
              _loadTasksForDate(_selectedCalendarDate);
            },
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: days.map((d) => Expanded(
          child: Center(
            child: Text(d,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _AppColors.textTertiary)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(
        _selectedCalendarDate.year, _selectedCalendarDate.month + 1, 0).day;
    final firstDay =
        DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, 1);
    final startWeekday = firstDay.weekday % 7;

    final List<Widget> rows = [];
    List<Widget> week = [];

    for (int i = 0; i < startWeekday; i++) {
      week.add(const Expanded(child: SizedBox(height: 28)));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date =
          DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, day);
      final hasTasks = _tasks.any((t) =>
          t.dueDate.year == date.year &&
          t.dueDate.month == date.month &&
          t.dueDate.day == day);
      final isSelected = _selectedCalendarDate.day == day &&
          _selectedCalendarDate.month == date.month;
      final isToday = DateTime.now().day == day &&
          DateTime.now().month == _selectedCalendarDate.month &&
          DateTime.now().year == _selectedCalendarDate.year;

      week.add(Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedCalendarDate = date);
            _loadTasksForDate(date);
          },
          child: Container(
            height: 28,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? _AppColors.accent
                  : isToday
                      ? _AppColors.accentLight
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? _AppColors.accent
                            : _AppColors.textPrimary,
                  ),
                ),
                if (hasTasks && !isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isToday ? _AppColors.accent : _AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));

      if (week.length == 7) {
        rows.add(Row(children: List<Widget>.from(week)));
        week = [];
      }
    }

    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(const Expanded(child: SizedBox(height: 34)));
      }
      rows.add(Row(children: List<Widget>.from(week)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  // ─── TASK CARD ────────────────────────────────────────────────────────────
  Widget _buildTaskCard(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final daysUntil = task.dueDate.difference(now).inDays;
    final isOverdue = !task.isCompleted && daysUntil < 0;
    final isDueSoon = !task.isCompleted && daysUntil <= 2 && daysUntil >= 0;
    final isToday = dueDay == today && !task.isCompleted;
    
    final hasReminder = task.alertDate != null;
    final reminderSoon = hasReminder && 
                        task.alertDate!.isAfter(now) && 
                        task.alertDate!.isBefore(now.add(const Duration(hours: 24))) &&
                        !task.isCompleted;
    
    final categoryColor = _getCategoryColor(task.category);
    final isStarred = _isStarred(task);

    Color statusColor;
    String statusText;
    Color statusBg;

    if (task.isCompleted) {
      statusColor = _AppColors.success;
      statusBg = _AppColors.successLight;
      statusText = 'Done';
    } else if (isOverdue) {
      statusColor = _AppColors.danger;
      statusBg = _AppColors.dangerLight;
      statusText = 'Overdue';
    } else if (reminderSoon) {
      statusColor = _AppColors.warning;
      statusBg = _AppColors.warningLight;
      statusText = 'Reminder Soon';
    } else if (isToday) {
      statusColor = _AppColors.accent;
      statusBg = _AppColors.accentLight;
      statusText = 'Today';
    } else if (isDueSoon) {
      statusColor = _AppColors.warning;
      statusBg = _AppColors.warningLight;
      statusText = 'Due Soon';
    } else {
      statusColor = _AppColors.textTertiary;
      statusBg = const Color(0xFFF1F5F9);
      statusText = 'Pending';
    }

    return GestureDetector(
      onTap: () => _showTaskDetails(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue ? _AppColors.danger.withOpacity(0.25) : _AppColors.border,
          ),
          boxShadow: [
            BoxShadow(color: _AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category_rounded, size: 12, color: categoryColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleStarred(task),
                        child: Icon(
                          isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 20,
                          color: isStarred ? _AppColors.starColor : _AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: task.isCompleted
                                    ? _AppColors.textTertiary
                                    : _AppColors.textPrimary,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasReminder)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.notifications_rounded,
                                size: 14,
                                color: reminderSoon 
                                    ? _AppColors.warning 
                                    : _AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: const TextStyle(
                              fontSize: 12, color: _AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (task.subCategory != null && task.subCategory!.isNotEmpty)
                                  Flexible(
                                    child: _metaChip(
                                      text: task.subCategory!,
                                      color: Colors.blue,
                                      icon: Icons.subdirectory_arrow_right_rounded,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: _metaChip(
                                    text: task.priority.toString().split('.').last,
                                    color: _getPriorityColor(task.priority),
                                    icon: _getPriorityIcon(task.priority),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: isOverdue ? _AppColors.danger : _AppColors.textTertiary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatDueDate(task.dueDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isOverdue ? _AppColors.danger : _AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (hasReminder && !task.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alarm_rounded,
                                size: 10,
                                color: reminderSoon ? _AppColors.warning : _AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Alert: ${DateFormat('MMM dd, hh:mm a').format(task.alertDate!)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: reminderSoon ? _AppColors.warning : _AppColors.textTertiary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _metaChip({required String text, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return GestureDetector(
      onTap: _addNewTask,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _AppColors.accent.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text('Create Task', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── CATEGORY FILTER DIALOG ───────────────────────────────────────────────
  void _showCategoryFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: _AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text('Filter by Category',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _AppColors.textPrimary)),
                  ],
                ),
              ),
              const Divider(height: 1, color: _AppColors.border),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _filterItem(
                      label: 'All Categories',
                      icon: Icons.apps_rounded,
                      color: _AppColors.accent,
                      isSelected: _selectedTaskCategory == null,
                      onTap: () {
                        setState(() {
                          _selectedTaskCategory = null;
                          _selectedSubCategory = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(
                        height: 1, indent: 20, endIndent: 20, color: _AppColors.border),
                    ..._masterCategories.map((cat) => Column(
                      children: [
                        _filterItem(
                          label: cat.name,
                          icon: Icons.label_rounded,
                          color: _getCategoryColor(cat.name),
                          isSelected: _selectedTaskCategory == cat.name,
                          onTap: () {
                            setState(() {
                              _selectedTaskCategory = cat.name;
                              _selectedSubCategory = null;
                            });
                            Navigator.pop(context);
                          },
                        ),
                        if (_selectedTaskCategory == cat.name && cat.subCategories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Column(
                              children: cat.subCategories.map((sub) => _filterItem(
                                label: '↳ ${sub.name}',
                                icon: Icons.subdirectory_arrow_right_rounded,
                                color: Colors.blue,
                                isSelected: _selectedSubCategory == sub.name,
                                onTap: () {
                                  setState(() {
                                    _selectedSubCategory = sub.name;
                                  });
                                  Navigator.pop(context);
                                },
                              )).toList(),
                            ),
                          ),
                      ],
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterItem({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      title: Text(label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: _AppColors.textPrimary,
          )),
      trailing:
          isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 20) : null,
    );
  }

  // ─── URGENT DIALOG ────────────────────────────────────────────────────────

  void _showUrgentTasksDialog(List<Task> urgentTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(
                color: _AppColors.danger,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Urgent Tasks (${urgentTasks.length})',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: urgentTasks.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 40, color: _AppColors.success),
                            SizedBox(height: 10),
                            Text('All clear!',
                                style:
                                    TextStyle(color: _AppColors.textSecondary)),
                          ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: urgentTasks.length,
                      itemBuilder: (_, i) => _buildTaskCard(urgentTasks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD TASK FLOW ────────────────────────────────────────────────────────

  void _addNewTask() {
    if (_masterCategories.isEmpty) {
      _loadMasterCategoriesForDialog();
    } else {
      _showCategorySelectionDialog();
    }
  }

  Future<void> _loadMasterCategoriesForDialog() async {
    if (!mounted) return;

    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _AppColors.accent),
                SizedBox(height: 16),
                Text('Loading categories...'),
              ]),
            ),
          ),
        );
      },
    );

    try {
      final response = await MyTasksService.getMasterCategories();
      if (dialogContext != null && mounted && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      if (mounted) {
        _processCategoriesResponse(response);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          if (_masterCategories.isEmpty) {
            _showNoCategoriesDialog();
          } else {
            _showCategorySelectionDialog();
          }
        }
      }
    } catch (e) {
      if (dialogContext != null && mounted && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      if (mounted) _showConnectionErrorDialog();
    }
  }

  void _showConnectionErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connection Error',
            style: TextStyle(
                color: _AppColors.accent, fontWeight: FontWeight.w700)),
        content: const Text('Unable to connect. Please check your connection.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadMasterCategoriesForDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showNoCategoriesDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('No Categories',
            style: TextStyle(
                color: _AppColors.accent, fontWeight: FontWeight.w700)),
        content:
            const Text('No task categories found. Would you like to add one?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Not Now')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCategoryDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Category',
              style: TextStyle(
                  color: _AppColors.accent, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _styledField(
                    controller: nameCtrl,
                    label: 'Category Name *',
                    enabled: !isSaving),
                const SizedBox(height: 12),
                _styledField(
                    controller: descCtrl,
                    label: 'Description (Optional)',
                    enabled: !isSaving,
                    maxLines: 2),
                const SizedBox(height: 8),
                Text(
                  'Note: You can add subcategories later',
                  style: TextStyle(fontSize: 11, color: _AppColors.textSecondary),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _AppColors.accent)),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ]),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _AppColors.textSecondary))),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        _showSnackBar(
                            'Please enter a category name', _AppColors.danger);
                        return;
                      }
                      ss(() => isSaving = true);
                      try {
                        final resp = await MyTasksService.saveMasterCategory(
                          name: name,
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                        );
                        if (resp['success'] == true) {
                          await MyTasksService.clearMasterCategoriesCache();
                          final updated = await MyTasksService.getMasterCategories();
                          if (mounted) {
                            Navigator.pop(ctx);
                            _processCategoriesResponse(updated);
                            _showSnackBar(
                                'Category "$name" added successfully', _AppColors.success);
                            await _refreshTasks();
                          }
                        } else {
                          throw Exception(resp['message'] ?? 'Failed to save category');
                        }
                      } catch (e) {
                        if (mounted) {
                          ss(() => isSaving = false);
                          _showSnackBar('Error: $e', _AppColors.danger);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isSaving ? 'Saving...' : 'Add Category'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySelectionDialog() {
    if (!mounted) return;
    if (_masterCategories.isEmpty) {
      _showAddCategoryDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _AppColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
                child: Row(
                  children: [
                    const Text('Create New Task',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: _AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _AppColors.border),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  shrinkWrap: true,
                  children: _masterCategories.map((cat) => _categoryDialogItem(
                        name: cat.name,
                        color: _getCategoryColor(cat.name),
                        icon: Icons.label_rounded,
                        onTap: () {
                          Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 100),
                              () {
                            if (mounted)
                              _showSubCategorySelectionDialog(cat);
                          });
                        },
                      )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryDialogItem({
    required String name,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showSubCategorySelectionDialog(MasterCategory category) async {
    if (!mounted) return;
  
  List<SubCategory> freshSubCategories = [];
  
  try {
    final categoryId = int.tryParse(category.id) ?? 0;
    debugPrint('Fetching subcategories for category ID: $categoryId, Category Name: ${category.name}');
    
    if (categoryId > 0) {
      final response = await MyTasksService.getSubCategoriesByCategoryId(categoryId: categoryId);
      debugPrint('Subcategories response data: ${response['data']}');
      
      if (response['data'] != null && response['data'] is List) {
        freshSubCategories = (response['data'] as List).map((item) {
          return SubCategory(
            id: item['id']?.toString() ?? '',
            name: item['subCategoryName'] ?? item['name'] ?? '',
            description: item['description'],
            categoryId: categoryId.toString(),
          );
        }).toList();
      }
    }
  } catch (e) {
    debugPrint('Error fetching subcategories: $e');
    freshSubCategories = category.subCategories.where((sub) => sub.categoryId == category.id).toList();
  }
  
  debugPrint('Final subcategories count: ${freshSubCategories.length}');
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Subcategory',
                            style: TextStyle(
                                fontSize: 12,
                                color: _AppColors.textSecondary)),
                        Text(category.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded,
                        color: _AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _AppColors.border),
            Flexible(
              child: freshSubCategories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category_rounded,
                                size: 40, color: _AppColors.textTertiary),
                            const SizedBox(height: 12),
                            const Text('No subcategories found for this category',
                                style: TextStyle(
                                    color: _AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddSubCategoryForCategoryDialog(category);
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Subcategory'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      shrinkWrap: true,
                      itemCount: freshSubCategories.length,
                      itemBuilder: (_, i) {
                        final sub = freshSubCategories[i];
                        return _categoryDialogItem(
                          name: sub.name,
                          color: Colors.blue,
                          icon: Icons.subdirectory_arrow_right_rounded,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAddEditTaskDialog(category, sub);
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddEditTaskDialog(category, null);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: _AppColors.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip Subcategory',
                      style: TextStyle(color: _AppColors.accent)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showAddSubCategoryForCategoryDialog(MasterCategory category) {
    final nameCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Subcategory to "${category.name}"',
              style: const TextStyle(color: _AppColors.accent, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _styledField(controller: nameCtrl, label: 'Subcategory Name *'),
            const SizedBox(height: 8),
            Text(
              'This subcategory will be linked to "${category.name}"',
              style: TextStyle(fontSize: 11, color: _AppColors.textSecondary),
            ),
            if (isSaving)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CircularProgressIndicator(color: _AppColors.accent)),
          ]),
          actions: [
            TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _AppColors.textSecondary))),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        _showSnackBar('Enter subcategory name', _AppColors.danger);
                        return;
                      }
                      ss(() => isSaving = true);
                      try {
                        final categoryId = int.tryParse(category.id) ?? 0;
                        if (categoryId == 0) {
                          throw Exception('Invalid category ID');
                        }
                        
                        final resp = await MyTasksService.saveSubCategory(
                          subCategoryName: name,
                          categoryId: categoryId,
                        );
                        
                        if (resp['success'] == true) {
                          await MyTasksService.clearMasterCategoriesCache();
                          final updated = await MyTasksService.getMasterCategories();
                          if (mounted) {
                            Navigator.pop(ctx);
                            _processCategoriesResponse(updated);
                            _showSnackBar('Subcategory "$name" added successfully', _AppColors.success);
                            await _refreshTasks();
                          }
                        } else {
                          throw Exception(resp['message'] ?? 'Failed to save subcategory');
                        }
                      } catch (e) {
                        if (mounted) {
                          ss(() => isSaving = false);
                          _showSnackBar('Error: $e', _AppColors.danger);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.accent,
                  foregroundColor: Colors.white),
              child: const Text('Add Subcategory'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD/EDIT TASK DIALOG ─────────────────────────────────────────────────

  void _showAddEditTaskDialog(MasterCategory category, SubCategory? subCategory, [Task? existingTask]) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final currentUserName = prefs.getString('userName') ?? prefs.getString('username') ?? '';

    final titleCtrl = TextEditingController(text: existingTask?.title ?? '');
    final descCtrl = TextEditingController(text: existingTask?.description ?? '');
    DateTime selectedDate = existingTask?.dueDate ?? DateTime.now();
    DateTime? alertDate = existingTask?.alertDate;
    DateTime? endDate = existingTask?.endDate;
    Priority selectedPriority = existingTask?.priority ?? Priority.medium;
    RepeatPattern selectedRepeatPattern = existingTask?.repeatPattern ?? RepeatPattern.never;
    int customRepeatDays = existingTask?.customRepeatDays ?? 1;
    String? assignedTo = existingTask?.assignedTo;
    String assignedBy = existingTask?.assignedBy ?? currentUserName;
    
    stt.SpeechToText? speech;
    bool isListening = false;
    final pageCtx = context;
    
    final isEdit = existingTask != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, ss) {
          speech ??= stt.SpeechToText();

          void listen() async {
            if (!isListening) {
              final available = await speech!.initialize();
              if (available) {
                ss(() => isListening = true);
                speech!.listen(onResult: (val) {
                  ss(() {
                    descCtrl.text = val.recognizedWords;
                    descCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: descCtrl.text.length));
                  });
                });
              }
            } else {
              ss(() => isListening = false);
              speech!.stop();
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: _AppColors.surface,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 520, maxHeight: 650),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category.name)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.task_alt_rounded,
                              color: _getCategoryColor(category.name),
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isEdit ? 'Edit Task' : 'Create New Task',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _AppColors.textSecondary)),
                                Text(category.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis),
                                if (subCategory != null)
                                  Text(subCategory.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _AppColors.accent),
                                      overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                        IconButton(
                          onPressed: () {
                            if (isListening) speech?.stop();
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: _AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _styledField(
                        controller: titleCtrl, label: 'Task Title *', maxLines: 3),
                    const SizedBox(height: 12),
                    _styledField(
  controller: descCtrl,
  label: 'Description',
  maxLines: 5,
  suffix: IconButton(
    icon: Icon(
      isListening
          ? Icons.mic_rounded
          : Icons.mic_none_rounded,
      color: isListening
          ? _AppColors.danger
          : _AppColors.accent,
      size: 24,
    ),
    onPressed: () async {
      if (!isListening) {
        final available = await speech!.initialize(
          onStatus: (status) => debugPrint('Speech status: $status'),
          onError: (error) => debugPrint('Speech error: $error'),
        );
        if (available) {
          ss(() => isListening = true);
          speech!.listen(
            onResult: (val) {
              ss(() {
                if (descCtrl.text.isEmpty) {
                  descCtrl.text = val.recognizedWords;
                } else {
                  descCtrl.text = '${descCtrl.text} ${val.recognizedWords}';
                }
                descCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: descCtrl.text.length));
              });
            },
          );
        }
      } else {
        ss(() => isListening = false);
        speech!.stop();
      }
    },
    padding: const EdgeInsets.all(8),
  ),
),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        _dateRow(
                          label: 'Due Date',
                          date: selectedDate,
                          icon: Icons.calendar_today_rounded,
                          color: _AppColors.accent,
                          onTap: () async {
                            final p = await _pickDate(
                                dialogCtx, selectedDate);
                            if (p != null) ss(() => selectedDate = p);
                          },
                        ),
                        const Divider(
                            height: 12, color: _AppColors.border),
                        _optionalDateRow(
                          label: 'Set Alert (Reminder)',
                          date: alertDate,
                          icon: Icons.notifications_active_rounded,
                          color: _AppColors.warning,
                          onTap: () async {
                            final p = await _pickDate(dialogCtx,
                                alertDate ?? selectedDate);
                            if (p != null) ss(() => alertDate = p);
                          },
                          onClear: () => ss(() => alertDate = null),
                        ),
                        const Divider(
                            height: 12, color: _AppColors.border),
                        _optionalDateRow(
                          label: 'Alert End Date',
                          date: endDate,
                          icon: Icons.event_rounded,
                          color: Colors.teal,
                          onTap: () async {
                            final p = await _pickDate(
                                dialogCtx, endDate ?? selectedDate);
                            if (p != null) ss(() => endDate = p);
                          },
                          onClear: () => ss(() => endDate = null),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _AppColors.border),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.repeat_rounded,
                            color: Colors.green.shade600, size: 20),
                        title: Text(
                          selectedRepeatPattern == RepeatPattern.never
                              ? 'Repeat'
                              : selectedRepeatPattern ==
                                      RepeatPattern.custom
                                  ? 'Every $customRepeatDays days'
                                  : _getRepeatPatternText(
                                      selectedRepeatPattern),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        trailing:
                            selectedRepeatPattern != RepeatPattern.never
                                ? GestureDetector(
                                    onTap: () => ss(() {
                                      selectedRepeatPattern =
                                          RepeatPattern.never;
                                      customRepeatDays = 1;
                                    }),
                                    child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: _AppColors.textSecondary),
                                  )
                                : const Icon(
                                    Icons.keyboard_arrow_right_rounded,
                                    color: _AppColors.textTertiary),
                        onTap: () => _showRepeatDialog(
                          dialogCtx,
                          ss,
                          selectedRepeatPattern,
                          (pattern, days) => ss(() {
                            selectedRepeatPattern = pattern;
                            if (pattern == RepeatPattern.custom &&
                                days != null) {
                              customRepeatDays = days;
                            }
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: Priority.values.map((p) {
                        final isSelected = selectedPriority == p;
                        final color = _getPriorityColor(p);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ss(() => selectedPriority = p),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 3),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.1)
                                    : _AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : _AppColors.border,
                                ),
                              ),
                              child: Column(children: [
                                Icon(_getPriorityIcon(p),
                                    size: 16,
                                    color: isSelected
                                        ? color
                                        : _AppColors.textTertiary),
                                const SizedBox(height: 3),
                                Text(
                                  p.toString().split('.').last,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? color
                                        : _AppColors.textTertiary,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _AppColors.border),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.person_add_rounded,
                                color: _AppColors.accent, size: 20),
                            title: const Text('Assigned To',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text(assignedTo?.isNotEmpty == true ? assignedTo! : 'Not assigned',
                                style: TextStyle(
                                    fontSize: 12, color: _AppColors.textSecondary)),
                            trailing: const Icon(Icons.edit_rounded,
                                size: 18, color: _AppColors.textTertiary),
                            onTap: () async {
                              final result = await _showAssignedToDialog(dialogCtx, assignedTo);
                              if (result != null) {
                                ss(() => assignedTo = result);
                              }
                            },
                          ),
                          const Divider(height: 1, color: _AppColors.border),
                          ListTile(
                            leading: Icon(Icons.person_rounded,
                                color: _AppColors.success, size: 20),
                            title: const Text('Assigned By',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text(assignedBy.isNotEmpty ? assignedBy : 'Current User',
                                style: TextStyle(
                                    fontSize: 12, color: _AppColors.textSecondary)),
                            trailing: Icon(Icons.info_outline_rounded,
                                size: 18, color: _AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (isListening) speech?.stop();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side:
                                const BorderSide(color: _AppColors.border),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color: _AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (isListening) speech?.stop();
                            if (titleCtrl.text.trim().isEmpty) {
                              _showSnackBar('Please enter task title',
                                  _AppColors.danger);
                              return;
                            }

                            final taskTitle = titleCtrl.text.trim();
                            final taskDesc = descCtrl.text.trim();
                            final taskDue = selectedDate;
                            final taskAlert = alertDate;
                            final taskEnd = endDate;
                            final taskPriority = selectedPriority;
                            final taskRepeat = selectedRepeatPattern;
                            final taskCustomDays = customRepeatDays;
                            Navigator.pop(ctx);

                            if (!mounted) return;
                            BuildContext? loadCtx;
                            showDialog(
                              context: pageCtx,
                              barrierDismissible: false,
                              builder: (c) {
                                loadCtx = c;
                                return Center(
                                  child: Card(
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(16))),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(
                                                color: _AppColors.accent),
                                            const SizedBox(height: 16),
                                            Text(isEdit ? 'Updating task...' : 'Creating task...'),
                                          ]),
                                    ),
                                  ),
                                );
                              },
                            );

                            try {
                              final now = DateTime.now();
                              final today = DateTime(
                                  now.year, now.month, now.day);
                              final taskDay = DateTime(taskDue.year,
                                  taskDue.month, taskDue.day);
                              
                              String taskStatus;
                              if (isEdit && existingTask?.isCompleted == true) {
                                taskStatus = 'COMPLETED';
                              } else if (taskDay == today) {
                                taskStatus = 'TODAY';
                              } else {
                                taskStatus = 'UPCOMING';
                              }
                              
                              final catId = int.tryParse(category.id) ?? 0;
                              int? subCatId;
                              if (subCategory != null && subCategory.id.isNotEmpty) {
                                subCatId = int.tryParse(subCategory.id);
                              }

                              String? repeatType;
                              String? repeatUnit;
                              int? repeatInterval;
                              switch (taskRepeat) {
                                case RepeatPattern.daily:
                                  repeatType = 'DAILY';
                                  repeatUnit = 'DAY';
                                  repeatInterval = 1;
                                  break;
                                case RepeatPattern.weekly:
                                  repeatType = 'WEEKLY';
                                  repeatUnit = 'WEEK';
                                  repeatInterval = 1;
                                  break;
                                case RepeatPattern.monthly:
                                  repeatType = 'MONTHLY';
                                  repeatUnit = 'MONTH';
                                  repeatInterval = 1;
                                  break;
                                case RepeatPattern.quarterly:
                                  repeatType = 'QUARTERLY';
                                  repeatUnit = 'MONTH';
                                  repeatInterval = 3;
                                  break;
                                case RepeatPattern.halfYearly:
                                  repeatType = 'HALF_YEARLY';
                                  repeatUnit = 'MONTH';
                                  repeatInterval = 6;
                                  break;
                                case RepeatPattern.yearly:
                                  repeatType = 'YEARLY';
                                  repeatUnit = 'YEAR';
                                  repeatInterval = 1;
                                  break;
                                case RepeatPattern.custom:
                                  repeatType = 'CUSTOM';
                                  repeatUnit = 'DAY';
                                  repeatInterval = taskCustomDays;
                                  break;
                                case RepeatPattern.never:
                                  break;
                              }

                            String formatDate(DateTime date) {
  // Convert local DateTime to UTC to preserve the actual date/time
  final utcDate = DateTime.utc(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
    date.second,
  );
  return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(utcDate);
}
                              Map<String, dynamic> resp;
                              
                              if (isEdit && existingTask?.realId != null) {
                                resp = await MyTasksService.updateTask(
                                  taskId: existingTask!.realId!,
                                  taskName: taskTitle,
                                  description: taskDesc,
                                  status: taskStatus,
                                  priority: taskPriority.toString().split('.').last.toUpperCase(),
                                  dueDate: formatDate(taskDue),
                                  reminderDatetime: taskAlert != null ? formatDate(taskAlert) : null,
                                  repeatType: repeatType,
                                  repeatInterval: repeatInterval,
                                  repeatUnit: repeatUnit,
                                  repeatEndDate: taskEnd != null ? formatDate(taskEnd) : null,
                                  assignedTo: assignedTo,
                                  assignedBy: assignedBy.isNotEmpty ? assignedBy : currentUserName,
                                  taskSubCategoryId: subCatId,
                                  taskCategoryId: catId,
                                  roleGroupName: 'Admin',
                                );
                              } else {
                                resp = await MyTasksService.saveTask(
                                  roleGroupName: 'Admin',
                                  taskCategoryId: catId,
                                  taskName: taskTitle,
                                  description: taskDesc,
                                  status: taskStatus,
                                  priority: taskPriority.toString().split('.').last.toUpperCase(),
                                  dueDate: formatDate(taskDue),
                                  reminderDatetime: taskAlert != null ? formatDate(taskAlert) : null,
                                  repeatType: repeatType,
                                  repeatInterval: repeatInterval,
                                  repeatUnit: repeatUnit,
                                  repeatEndDate: taskEnd != null ? formatDate(taskEnd) : null,
                                  assignedTo: assignedTo,
                                  assignedBy: assignedBy.isNotEmpty ? assignedBy : currentUserName,
                                  taskSubCategoryId: subCatId,
                                );
                              }

                              if (loadCtx != null && Navigator.canPop(loadCtx!)) {
                                if (mounted) Navigator.pop(loadCtx!);
                              }

                              if (!mounted) return;

                              if (resp['status_code'] == 200 ||
                                  resp['status_code'] == 201 ||
                                  resp['success'] == true) {
                                await _refreshTasks();
                                _showSnackBar(
                                    isEdit ? 'Task updated!' : 'Task created!', 
                                    _AppColors.success);
                              } else {
                                throw Exception(resp['message'] ?? 'Failed to save task');
                              }
                            } catch (e) {
                              if (loadCtx != null && Navigator.canPop(loadCtx!)) {
                                if (mounted) Navigator.pop(loadCtx!);
                              }
                              if (mounted)
                                _showSnackBar(
                                    'Error: $e', _AppColors.danger);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.accent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEdit ? 'Update Task' : 'Create Task',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
Future<String?> _showAssignedToDialog(BuildContext context, String? currentValue) async {
  List<Map<String, dynamic>> userList = [];
  
  try {
    final response = await MyTasksService.getClinicUserList();
    debugPrint('Raw assign dialog response keys: ${response.keys.toList()}');
    
    List<dynamic>? rawList;

    // Structure: { "data": [ { "userlist": [...] } ] }
    if (response['data'] != null && response['data'] is List) {
      final dataList = response['data'] as List;
      if (dataList.isNotEmpty && dataList[0] is Map) {
        final firstItem = dataList[0] as Map;
        if (firstItem['userlist'] != null && firstItem['userlist'] is List) {
          rawList = firstItem['userlist'] as List;
        }
      }
    }

    // Fallback: { "userlist": [...] } directly
    if (rawList == null && response['userlist'] != null && response['userlist'] is List) {
      rawList = response['userlist'] as List;
    }

    // Last resort: find any List anywhere in response
    if (rawList == null) {
      for (final value in response.values) {
        if (value is List && value.isNotEmpty) {
          rawList = value;
          break;
        }
      }
    }

    debugPrint('rawList found: ${rawList?.length} items');

    if (rawList != null) {
      userList = rawList.map((user) {
        final name = user['username']?.toString() ??
            user['name']?.toString() ??
            user['userName']?.toString() ??
            user['fullName']?.toString() ?? '';
        return <String, dynamic>{
          'id': user['id']?.toString() ?? '',
          'name': name,
          'userid': user['userid']?.toString() ?? '',
        };
      }).where((user) => (user['name'] as String).isNotEmpty).toList();
    }
  } catch (e) {
    debugPrint('Error fetching user list: $e');
  }

  debugPrint('Final userList count: ${userList.length}');
  if (userList.isNotEmpty) debugPrint('First user: ${userList.first}');

  if (!mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String searchQuery = '';
      return StatefulBuilder(
        builder: (ctx, ss) {
          final filtered = searchQuery.isEmpty
              ? userList
              : userList
                  .where((u) =>
                      (u['name'] as String).toLowerCase().contains(searchQuery))
                  .toList();

          return AlertDialog(
            title: const Text('Assign Task To',
                style: TextStyle(
                    color: _AppColors.accent, fontWeight: FontWeight.w700)),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) =>
                        ss(() => searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: userList.isEmpty
                        ? const Center(
                            child: Text('No users found',
                                style: TextStyle(
                                    color: _AppColors.textSecondary)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final user = filtered[index];
                              final userName = user['name'] as String;
                              final userId = user['userid'] as String;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _AppColors.accent.withOpacity(0.1),
                                  radius: 18,
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: _AppColors.accent,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(userName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                subtitle: userId.isNotEmpty
                                    ? Text('@$userId',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _AppColors.textSecondary))
                                    : null,
                                onTap: () => Navigator.pop(ctx, userName),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme:
              const ColorScheme.light(primary: _AppColors.accent),
        ),
        child: child!,
      ),
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _AppColors.textPrimary)),
          const Spacer(),
          Text(DateFormat('MMM dd, yyyy').format(date),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: _AppColors.textTertiary),
        ]),
      ),
    );
  }

  Widget _optionalDateRow({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon,
              size: 16,
              color: date != null ? color : _AppColors.textTertiary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    date != null ? color : _AppColors.textSecondary,
              )),
          const Spacer(),
          if (date != null) ...[
            Text(DateFormat('MMM dd, yyyy').format(date),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: _AppColors.textTertiary),
            ),
          ] else
            const Icon(Icons.add_rounded,
                size: 16, color: _AppColors.textTertiary),
        ]),
      ),
    );
  }

  void _showRepeatDialog(
    BuildContext ctx,
    StateSetter ss,
    RepeatPattern current,
    Function(RepeatPattern, int?) onSelected,
  ) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Repeat',
            style: TextStyle(
                color: _AppColors.accent, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ...RepeatPattern.values.map((p) {
              if (p == RepeatPattern.custom) {
                return ListTile(
                  title: const Text('Custom'),
                  leading: Radio<RepeatPattern>(
                    value: p,
                    groupValue: current,
                    onChanged: (v) {
                      Navigator.pop(c);
                      _showCustomDaysDialog(
                          ctx, (days) => onSelected(v!, days));
                    },
                  ),
                );
              }
              return ListTile(
                title: Text(p == RepeatPattern.never
                    ? 'Never'
                    : p.toString().split('.').last),
                leading: Radio<RepeatPattern>(
                  value: p,
                  groupValue: current,
                  onChanged: (v) {
                    Navigator.pop(c);
                    if (v != null) onSelected(v, null);
                  },
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }

  void _showCustomDaysDialog(BuildContext ctx, Function(int) onSelected) {
    int days = 1;
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Custom Repeat',
            style: TextStyle(
                color: _AppColors.accent, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Repeat every'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  hintText: 'Days',
                ),
                onChanged: (v) => days = int.tryParse(v) ?? 1,
              ),
            ),
            const SizedBox(width: 8),
            const Text('days'),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              onSelected(days);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        snap: true,
        snapSizes: const [0.5, 0.85, 0.95],
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                color: _AppColors.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
Row(
  children: [
    GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Icon(
        _isStarred(task) ? Icons.star_rounded : Icons.star_outline_rounded,
        color: _isStarred(task) ? _AppColors.starColor : _AppColors.textTertiary,
        size: 24,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(task.title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.textPrimary)),
              const SizedBox(width: 8),
              if (task.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Completed',
                      style: TextStyle(
                          fontSize: 11,
                          color: _AppColors.success,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    ),
  ],
),
                                const SizedBox(width: 12),
                                const Text('Task Details',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: _AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded,
                                color: _AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _AppColors.border),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: controller,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: controller,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: 20, right: 20, top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(task.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category_rounded,
                                  size: 18, color: _getCategoryColor(task.category)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(task.category,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _getCategoryColor(task.category))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5, height: 52,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(task.category),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task.title,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: task.isCompleted
                                              ? _AppColors.textTertiary
                                              : _AppColors.textPrimary,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null)),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, children: [
                                    if (task.subCategory != null &&
                                        task.subCategory!.isNotEmpty)
                                      _metaChip(
                                          text: task.subCategory!,
                                          color: Colors.blue,
                                          icon: Icons.subdirectory_arrow_right_rounded),
                                    _metaChip(
                                        text: task.priority
                                            .toString()
                                            .split('.')
                                            .last,
                                        color: _getPriorityColor(task.priority),
                                        icon: _getPriorityIcon(task.priority)),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                          _detailRow(
                              icon: Icons.person_add_rounded,
                              label: 'Assigned To',
                              value: task.assignedTo!,
                              color: _AppColors.accent),
                        if (task.assignedBy != null && task.assignedBy!.isNotEmpty)
                          _detailRow(
                              icon: Icons.person_rounded,
                              label: 'Assigned By',
                              value: task.assignedBy!,
                              color: _AppColors.success),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Description',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SingleChildScrollView(
                              child: Text(task.description,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: _AppColors.textPrimary,
                                      height: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            color: _AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            _detailRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Due Date',
                                value: DateFormat('EEEE, MMMM dd, yyyy')
                                    .format(task.dueDate),
                                color: _AppColors.accent),
                            const Divider(height: 1, color: _AppColors.border),
                            _detailRow(
                                icon: Icons.notifications_active_rounded,
                                label: 'Alert Date',
                                value: task.alertDate != null
                                    ? DateFormat('EEEE, MMMM dd, yyyy - hh:mm a')
                                        .format(task.alertDate!)
                                    : 'No alert set',
                                color: task.alertDate != null
                                    ? _AppColors.warning
                                    : _AppColors.textTertiary),
                            const Divider(height: 1, color: _AppColors.border),
                            _detailRow(
                                icon: Icons.event_rounded,
                                label: 'End Date',
                                value: task.endDate != null
                                    ? DateFormat('EEEE, MMMM dd, yyyy')
                                        .format(task.endDate!)
                                    : 'No end date set',
                                color: task.endDate != null
                                    ? Colors.teal
                                    : _AppColors.textTertiary),
                            if (task.repeatPattern != RepeatPattern.never) ...[
                              const Divider(height: 1, color: _AppColors.border),
                              _detailRow(
                                  icon: Icons.repeat_rounded,
                                  label: 'Repeat',
                                  value: task.repeatPattern ==
                                          RepeatPattern.custom
                                      ? 'Every ${task.customRepeatDays} days'
                                      : _getRepeatPatternText(
                                          task.repeatPattern),
                                  color: Colors.green),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                final category = _masterCategories.firstWhere(
                                  (c) => c.name == task.category,
                                  orElse: () => MasterCategory(
                                      id: '0',
                                      name: task.category,
                                      isActive: true),
                                );
                                final subCategory =
                                    category.subCategories.firstWhere(
                                  (s) => s.name == task.subCategory,
                                  orElse: () => SubCategory(
                                      id: '', name: '', categoryId: ''),
                                );
                                _showAddEditTaskDialog(
                                    category,
                                    subCategory.name.isNotEmpty
                                        ? subCategory
                                        : null,
                                    task);
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: _AppColors.accent),
                              ),
                              icon: const Icon(Icons.edit_rounded,
                                  size: 18, color: _AppColors.accent),
                              label: const Text('Edit Task',
                                  style:
                                      TextStyle(color: _AppColors.accent)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: task.realId == null
                                  ? null
                                  : () {
                                      _updateTaskStatus(
                                          task, !task.isCompleted);
                                      Navigator.pop(context);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: task.isCompleted
                                    ? _AppColors.textTertiary
                                    : _AppColors.accent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                task.realId == null
                                    ? 'No ID'
                                    : (task.isCompleted
                                        ? 'Mark Pending'
                                        : 'Mark Complete'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        const Text('Comments',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        _buildAddCommentSection(task),
                        const SizedBox(height: 10),
                        if (task.comments != null && task.comments!.isNotEmpty)
                          ...task.comments!.map(_buildCommentCard),
                        const SizedBox(height: 20),
                      ],
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

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13, 
                  color: value.contains('No ') ? _AppColors.textTertiary : _AppColors.textPrimary,
                  fontWeight: value.contains('No ') ? FontWeight.normal : FontWeight.w500),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // ─── COMMENT SECTION ──────────────────────────────────────────────────────
Widget _buildAddCommentSection(Task task) {
  final commentCtrl = TextEditingController();
  stt.SpeechToText? speech;
  bool isListening = false;
  bool isGettingLocation = false;
  String? currentLocation;
  Position? currentPosition;
  final FocusNode commentFocusNode = FocusNode();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay =
      DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  bool canAddComment = !task.isCompleted;

  if (task.repeatPattern != RepeatPattern.never && !task.isCompleted) {
    if (task.repeatPattern == RepeatPattern.weekly) {
      canAddComment = dueDay.weekday == today.weekday;
    } else if (task.repeatPattern == RepeatPattern.monthly) {
      canAddComment = dueDay.day == today.day;
    } else if (task.repeatPattern == RepeatPattern.yearly) {
      canAddComment =
          dueDay.month == today.month && dueDay.day == today.day;
    }
  }

  return StatefulBuilder(
    builder: (ctx, ss) {
      speech ??= stt.SpeechToText();

      void listen() async {
        if (!isListening) {
          final available = await speech!.initialize(
            onStatus: (status) => debugPrint('Speech status: $status'),
            onError: (error) => debugPrint('Speech error: $error'),
          );
          if (available) {
            ss(() => isListening = true);
            speech!.listen(
              onResult: (val) {
                ss(() {
                  if (commentCtrl.text.isEmpty) {
                    commentCtrl.text = val.recognizedWords;
                  } else {
                    commentCtrl.text = '${commentCtrl.text} ${val.recognizedWords}';
                  }
                  commentCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: commentCtrl.text.length));
                });
              },
            );
          }
        } else {
          ss(() => isListening = false);
          speech!.stop();
        }
      }

      void getLocation() async {
        ss(() => isGettingLocation = true);
        try {
          PermissionStatus permissionStatus = await Permission.location.status;
          
          if (!permissionStatus.isGranted) {
            permissionStatus = await Permission.location.request();
          }
          
          if (permissionStatus.isGranted) {
            final enabled = await Geolocator.isLocationServiceEnabled();
            if (!enabled) {
              _showSnackBar(
                  'Please enable location services in your device settings', 
                  _AppColors.warning);
              await Geolocator.openLocationSettings();
              ss(() => isGettingLocation = false);
              return;
            }
            
            LocationSettings locationSettings = const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            );
            
            currentPosition = await Geolocator.getCurrentPosition(
              locationSettings: locationSettings,
            ).timeout(const Duration(seconds: 30));
            
            final placemarks = await placemarkFromCoordinates(
              currentPosition!.latitude,
              currentPosition!.longitude,
            );
            
            if (placemarks.isNotEmpty) {
              final pm = placemarks.first;
              currentLocation = [
                pm.name,
                pm.subLocality,
                pm.locality,
                pm.administrativeArea,
                pm.country,
              ].where((part) => part != null && part.isNotEmpty).join(', ');
              
              if (currentLocation!.isEmpty) {
                currentLocation = '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}';
              }
            } else {
              currentLocation = '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}';
            }
            
            ss(() {});
            _showSnackBar('Location captured: $currentLocation', _AppColors.success);
          } else {
            _showSnackBar(
                'Location permission denied. Please enable location permission in app settings.', 
                _AppColors.danger);
            await openAppSettings();
          }
        } catch (e) {
          debugPrint('Error getting location: $e');
          _showSnackBar('Error getting location: ${e.toString()}', _AppColors.danger);
        } finally {
          ss(() => isGettingLocation = false);
        }
      }

      if (!canAddComment) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _AppColors.textSecondary, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Comments only on ${task.repeatPattern.toString().split('.').last} basis',
                style: const TextStyle(
                    fontSize: 12, color: _AppColors.textSecondary),
              ),
            ),
          ]),
        );
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: commentCtrl,
                focusNode: commentFocusNode,
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      fontSize: 13, color: _AppColors.textTertiary),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
                onEditingComplete: () {
                  commentFocusNode.unfocus();
                },
              ),
            ),
            IconButton(
              icon: Icon(
                  isListening
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  color: isListening
                      ? _AppColors.danger
                      : _AppColors.accent,
                  size: 24),
              onPressed: listen,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: isGettingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _AppColors.accent))
                  : Icon(Icons.location_on_rounded,
                      color: currentLocation != null
                          ? _AppColors.success
                          : _AppColors.textTertiary,
                      size: 24),
              onPressed: getLocation,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded,
                  color: _AppColors.accent, size: 24),
              onPressed: () {
                final comment = commentCtrl.text.trim();
                if (comment.isNotEmpty || currentLocation != null) {
                  _addCommentToTask(
                      task, comment, currentLocation, currentPosition);
                  commentCtrl.clear();
                  commentFocusNode.unfocus();
                  ss(() {
                    currentLocation = null;
                    currentPosition = null;
                  });
                  Navigator.pop(ctx);
                } else {
                  _showSnackBar(
                      'Enter a comment or add location',
                      _AppColors.warning);
                }
              },
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ]),
          if (currentLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 12, color: _AppColors.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(currentLocation!,
                      style: const TextStyle(
                          fontSize: 11, color: _AppColors.success),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
        ]),
      );
    },
  );
}
  Widget _buildCommentCard(TaskComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(comment.text,
                style: const TextStyle(
                    fontSize: 13, color: _AppColors.textPrimary)),
          ),
          Text(DateFormat('MMM dd, HH:mm').format(comment.createdAt),
              style: const TextStyle(
                  fontSize: 10, color: _AppColors.textTertiary)),
        ]),
        if (comment.location != null && comment.location!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 11, color: _AppColors.success),
              const SizedBox(width: 3),
              Expanded(
                child: Text(comment.location!,
                    style: const TextStyle(
                        fontSize: 11, color: _AppColors.success),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        if (comment.latitude != null && comment.longitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Icon(Icons.pin_drop_rounded,
                  size: 11, color: _AppColors.textTertiary),
              const SizedBox(width: 3),
              Text(
                '${comment.latitude!.toStringAsFixed(4)}, ${comment.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(
                    fontSize: 10, color: _AppColors.textTertiary),
              ),
            ]),
          ),
      ]),
    );
  }

  Future<void> _addCommentToTask(Task task, String comment,
      String? location, Position? position) async {
    if (!mounted) return;
    try {
      double? lat, lng;
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
      if (task.realId != null) {
        final resp = await MyTasksService.addTaskComment(
          taskId: task.realId!,
          comment: comment,
          locationName: location,
          latitude: lat,
          longitude: lng,
        );
        if (resp['success'] == true) {
          final newComment = TaskComment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: comment,
            location: location,
            latitude: lat,
            longitude: lng,
            createdAt: DateTime.now(),
          );
          setState(() {
            task.comments ??= [];
            task.comments!.add(newComment);
          });
          _showSnackBar('Comment added', _AppColors.success);
        } else {
          throw Exception(resp['message'] ?? 'Failed');
        }
      } else {
        _showSnackBar(
            'Cannot add comment: Task ID missing', _AppColors.warning);
      }
    } catch (e) {
      _showSnackBar('Error: $e', _AppColors.danger);
    }
  }

  Future<void> _updateTaskStatus(Task task, bool markComplete) async {
    if (task.realId == null) {
      _showSnackBar('This task has no backend ID', _AppColors.warning);
      return;
    }

    BuildContext? loadCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadCtx = ctx;
        return const Center(
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _AppColors.accent),
                SizedBox(height: 16),
                Text('Updating task...'),
              ]),
            ),
          ),
        );
      },
    );

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);

      String newStatus;
      if (markComplete) {
        newStatus = 'COMPLETED';
      } else {
        if (dueDay == today) {
          newStatus = 'TODAY';
        } else if (task.dueDate.isAfter(now)) {
          newStatus = 'UPCOMING';
        } else {
          newStatus = 'TODAY'; 
        }
      }

      String? repeatType;
      String? repeatUnit;
      int? repeatInterval;
      switch (task.repeatPattern) {
        case RepeatPattern.daily:
          repeatType = 'DAILY'; repeatUnit = 'DAY'; repeatInterval = 1;
          break;
        case RepeatPattern.weekly:
          repeatType = 'WEEKLY'; repeatUnit = 'WEEK'; repeatInterval = 1;
          break;
        case RepeatPattern.monthly:
          repeatType = 'MONTHLY'; repeatUnit = 'MONTH'; repeatInterval = 1;
          break;
        case RepeatPattern.quarterly:
          repeatType = 'QUARTERLY'; repeatUnit = 'MONTH'; repeatInterval = 3;
          break;
        case RepeatPattern.halfYearly:
          repeatType = 'HALF_YEARLY'; repeatUnit = 'MONTH'; repeatInterval = 6;
          break;
        case RepeatPattern.yearly:
          repeatType = 'YEARLY'; repeatUnit = 'YEAR'; repeatInterval = 1;
          break;
        case RepeatPattern.custom:
          repeatType = 'CUSTOM'; repeatUnit = 'DAY'; repeatInterval = task.customRepeatDays;
          break;
        case RepeatPattern.never:
          break;
      }

      String formatDate(DateTime date) =>
          DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(date);

      final resp = await MyTasksService.updateTask(
        taskId: task.realId!,
        taskName: task.title,
        description: task.description,
        status: newStatus,
        priority: task.priority.toString().split('.').last.toUpperCase(),
        dueDate: formatDate(task.dueDate),
        reminderDatetime: task.alertDate != null ? formatDate(task.alertDate!) : null,
        repeatType: repeatType,
        repeatInterval: repeatInterval,
        repeatUnit: repeatUnit,
        repeatEndDate: task.endDate != null ? formatDate(task.endDate!) : null,
        assignedTo: task.assignedTo,
        assignedBy: task.assignedBy,
        taskCategoryId: null,   
        taskSubCategoryId: null, 
        roleGroupName: 'Admin',
      );

      if (mounted && loadCtx != null && Navigator.canPop(loadCtx!)) {
        Navigator.pop(loadCtx!);
      }

      if (resp['success'] == true ||
          resp['status_code'] == 200 ||
          resp['status_code'] == 201) {
        if (mounted) {
          await _refreshTasks();
          _showSnackBar(
            markComplete ? 'Task marked as completed' : 'Task marked as pending',
            _AppColors.success,
          );
        }
      } else {
        throw Exception(resp['message'] ?? 'Failed to update task');
      }
    } catch (e) {
      if (mounted && loadCtx != null && Navigator.canPop(loadCtx!)) {
        Navigator.pop(loadCtx!);
      }
      if (mounted) _showSnackBar('Failed to update: $e', _AppColors.danger);
    }
  }

  // ─── HELPER WIDGET ────────────────────────────────────────────────────────

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontSize: 13, color: _AppColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: _AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ─── MODEL CLASSES ────────────────────────────────────────────────────────────

class SubCategory {
  final String id;
  final String name;
  final String? description;
  final String categoryId;

  SubCategory({
    required this.id,
    required this.name,
    this.description,
    this.categoryId = '',
  });
}

class TaskComment {
  final String id;
  final String text;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.text,
    this.location,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });
}

class MasterCategory {
  final String id;
  final String name;
  final String? description;
  final String? code;
  final bool isActive;
  final List<SubCategory> subCategories;

  MasterCategory({
    required this.id,
    required this.name,
    this.description,
    this.code,
    required this.isActive,
    this.subCategories = const [],
  });

  factory MasterCategory.fromJson(Map<String, dynamic> json) {
    List<SubCategory> subs = [];
    if (json['subCategories'] != null && json['subCategories'] is List) {
      subs = (json['subCategories'] as List)
          .map((item) => SubCategory(
                id: item['id']?.toString() ?? '',
                name: item['name'] ?? item['subCategoryName'] ?? '',
                description: item['description'],
                categoryId: item['categoryId']?.toString() ?? '',
              ))
          .toList();
    }
    return MasterCategory(
      id: json['id']?.toString() ?? json['categoryId']?.toString() ?? '',
      name: json['name'] ?? json['categoryName'] ?? '',
      description: json['description'],
      code: json['code'],
      isActive: json['isActive'] ?? json['active'] ?? true,
      subCategories: subs,
    );
  }
}

class Task {
  final int? realId;
  final String title;
  final String description;
  final DateTime dueDate;
  final DateTime? alertDate;
  final DateTime? endDate;
  final RepeatPattern repeatPattern;
  final int customRepeatDays;
  final Priority priority;
  bool isCompleted;
  String status;
  final String category;
  final String? subCategory;
  List<TaskComment>? comments;
  final String? assignedTo;
  final String? assignedBy;

  Task({
    this.realId,
    required this.title,
    required this.description,
    required this.dueDate,
    this.alertDate,
    this.endDate,
    this.repeatPattern = RepeatPattern.never,
    this.customRepeatDays = 1,
    required this.priority,
    required this.isCompleted,
    required this.status,
    required this.category,
    this.subCategory,
    this.comments,
    this.assignedTo,
    this.assignedBy,
  });

  factory Task.fromJson(Map<String, dynamic> json, String statusFromApi) {
    DateTime dueDate;
    try {
      final rawDate = json['dueDate'] ??
          json['taskDate'] ??
          json['reminderDatetime'] ??
          json['createdDate'] ??
          json['date'] ??
          json['dueDate'];

      if (rawDate != null) {
        dueDate = DateTime.parse(rawDate.toString());
      } else {
        dueDate = DateTime.now();
        debugPrint('⚠️ No date found for task "${json['taskName']}". '
            'Available keys: ${json.keys.toList()}');
      }
    } catch (e) {
      debugPrint('Error parsing dueDate: $e, raw value: ${json['dueDate']}');
      dueDate = DateTime.now();
    }

    DateTime? alertDate;
    final rawAlertDate = json['reminderDatetime'] ?? json['alertDate'] ?? json['alertDatetime'];
    if (rawAlertDate != null) {
      try {
        alertDate = DateTime.parse(rawAlertDate.toString());
      } catch (_) {}
    }

    DateTime? endDate;
    if (json['repeatEndDate'] != null) {
      try {
        endDate = DateTime.parse(json['repeatEndDate'].toString());
      } catch (_) {}
    } else if (json['endDate'] != null) {
      try {
        endDate = DateTime.parse(json['endDate'].toString());
      } catch (_) {}
    }

    RepeatPattern repeatPattern = RepeatPattern.never;
    if (json['repeatPattern'] != null) {
      final p = json['repeatPattern'].toString().toLowerCase();
      if (p.contains('daily')) repeatPattern = RepeatPattern.daily;
      else if (p.contains('weekly')) repeatPattern = RepeatPattern.weekly;
      else if (p.contains('monthly')) repeatPattern = RepeatPattern.monthly;
      else if (p.contains('half')) repeatPattern = RepeatPattern.halfYearly;
      else if (p.contains('quarter')) repeatPattern = RepeatPattern.quarterly;
      else if (p.contains('yearly')) repeatPattern = RepeatPattern.yearly;
      else if (p.contains('custom')) repeatPattern = RepeatPattern.custom;
    }

    int customRepeatDays = json['customRepeatDays'] ?? 1;

    Priority priority = Priority.medium;
    final ps = json['priority']?.toString().toLowerCase() ?? '';
    if (ps.contains('high')) priority = Priority.high;
    else if (ps.contains('low')) priority = Priority.low;

    bool isCompleted = statusFromApi == 'COMPLETED' ||
        json['status']?.toString().toLowerCase() == 'completed' ||
        json['isCompleted'] == true;

    int? realId;
    if (json['id'] != null && json['id'].toString().isNotEmpty) {
      realId = int.tryParse(json['id'].toString());
    } else if (json['taskId'] != null && json['taskId'].toString().isNotEmpty) {
      realId = int.tryParse(json['taskId'].toString());
    }

    List<TaskComment>? comments;
    if (json['comments'] != null && json['comments'] is List) {
      comments = (json['comments'] as List)
          .map((item) => TaskComment(
                id: item['id']?.toString() ?? '',
                text: item['text'] ?? item['comment'] ?? '',
                location: item['location'],
                latitude: item['latitude'] != null
                    ? double.tryParse(item['latitude'].toString())
                    : null,
                longitude: item['longitude'] != null
                    ? double.tryParse(item['longitude'].toString())
                    : null,
                createdAt: item['createdAt'] != null
                    ? DateTime.parse(item['createdAt'].toString())
                    : DateTime.now(),
              ))
          .toList();
    }

    String categoryName = 'General';
    if (json['categoryName'] != null && json['categoryName'].toString().isNotEmpty) {
      categoryName = json['categoryName'].toString();
    } else if (json['category'] != null && json['category'].toString().isNotEmpty) {
      categoryName = json['category'].toString();
    } else if (json['taskCategory'] != null && json['taskCategory'].toString().isNotEmpty) {
      categoryName = json['taskCategory'].toString();
    } else if (json['taskCategoryName'] != null && json['taskCategoryName'].toString().isNotEmpty) {
      categoryName = json['taskCategoryName'].toString();
    }

    return Task(
      realId: realId,
      title: json['taskName'] ?? json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? json['discription'] ?? '',
      dueDate: dueDate,
      alertDate: alertDate,
      endDate: endDate,
      repeatPattern: repeatPattern,
      customRepeatDays: customRepeatDays,
      priority: priority,
      isCompleted: isCompleted,
      status: statusFromApi.toLowerCase(),
      category: categoryName,
      subCategory: json['subCategoryName'] ?? json['subCategory'],
      comments: comments,
      assignedTo: json['assignedTo']?.toString(),
      assignedBy: json['assignedBy']?.toString(),
    );
  }
}

enum Priority { high, medium, low }
enum RepeatPattern { never, daily, weekly, monthly, halfYearly, quarterly, yearly, custom }
enum TaskStatus { today, upcoming, completed, overdue, dueSoon, pending }