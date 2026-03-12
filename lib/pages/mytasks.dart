import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/services/my_tasks_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> with AutomaticKeepAliveClientMixin {
  String? _selectedTaskCategory;
  final List<Task> _tasks = [];
  List<MasterCategory> _masterCategories = [];
  bool _isLoadingTasks = false;
  final List<String> _statusCategories = ['Today', 'Upcoming', 'Completed'];
  int _selectedStatusIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFilterVisible = false;
  
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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTasks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingTasks = true;
    });
    
    try {
      await Future.wait([
        _fetchTasksByStatus('TODAY'),
        _fetchTasksByStatus('UPCOMING'),
        _fetchTasksByStatus('COMPLETED'),
      ]);
      
      _mergeAllTasks();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
        });
      }
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
      
      if (mounted) {
        _processTasksResponse(response, status);
      }
    } catch (e) {
      debugPrint('Error fetching tasks for status $status: $e');
      if (mounted) {
        setState(() {
          _tasksByStatus[status] = [];
        });
      }
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
    } else if (response is List) {
      tasksData = response as List;
    }
    
    if (mounted) {
      setState(() {
        final List<Task> tasks = [];
        
        for (var item in tasksData) {
          if (item is Map<String, dynamic>) {
            try {
              final task = Task.fromJson(item, status);
              tasks.add(task);
            } catch (e) {
              debugPrint('❌ Error parsing task: $e');
            }
          }
        }
        
        _tasksByStatus[status] = tasks;
      });
    }
  }

  void _mergeAllTasks() {
    final allTasks = <Task>[];
    
    _tasksByStatus.forEach((status, tasks) {
      allTasks.addAll(tasks);
    });
    
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

      try {
        final response = await MyTasksService.getMasterCategories();
        if (mounted) {
          _processCategoriesResponse(response);
        }
        return;
      } catch (e) {
        debugPrint('Failed to fetch master categories: $e');
      }
      
      if (mounted) {
        setState(() {
          _masterCategories = [];
        });
      }
      
    } catch (e) {
      debugPrint('Error loading master categories: $e');
      if (mounted) {
        setState(() {
          _masterCategories = [];
        });
      }
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
          if (item is Map<String, dynamic>) {
            return MasterCategory.fromJson(item);
          }
          return MasterCategory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: item.toString(),
            description: null,
            code: null,
            isActive: true,
          );
        }).toList();
        
        _masterCategories.sort((a, b) => a.name.compareTo(b.name));
      });
    }
  }
  
  Future<void> _refreshTasks() async {
    await MyTasksService.clearTasksCache();
    await _loadAllTasks();
  }
  
  Future<void> _updateTaskStatus(Task task, bool isCompleted) async {
    if (task.realId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This task cannot be updated because it has no ID from backend'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    BuildContext? loadingContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        loadingContext = ctx;
        return const Center(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Updating task...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final newStatus = isCompleted ? 'COMPLETED' : 'UPCOMING';
      
      final response = await MyTasksService.updateTaskStatus(
        taskId: task.realId!,
        status: newStatus,
      );
      
      if (mounted && loadingContext != null && Navigator.canPop(loadingContext!)) {
        Navigator.pop(loadingContext!);
      }

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            task.isCompleted = isCompleted;
            
            if (isCompleted) {
              task.status = 'completed';
              _tasksByStatus['TODAY']?.removeWhere((t) => t.realId == task.realId);
              _tasksByStatus['UPCOMING']?.removeWhere((t) => t.realId == task.realId);
              
              if (!_tasksByStatus['COMPLETED']!.any((t) => t.realId == task.realId)) {
                _tasksByStatus['COMPLETED']!.add(task);
              }
            } else {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final taskDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
              
              task.status = taskDay == today ? 'today' : 'upcoming';
              _tasksByStatus['COMPLETED']?.removeWhere((t) => t.realId == task.realId);
              
              if (taskDay == today) {
                if (!_tasksByStatus['TODAY']!.any((t) => t.realId == task.realId)) {
                  _tasksByStatus['TODAY']!.add(task);
                }
              } else {
                if (!_tasksByStatus['UPCOMING']!.any((t) => t.realId == task.realId)) {
                  _tasksByStatus['UPCOMING']!.add(task);
                }
              }
            }
            
            _mergeAllTasks();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Task marked as ${isCompleted ? "completed" : "pending"}'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to update task');
      }
    } catch (e) {
      if (mounted && loadingContext != null && Navigator.canPop(loadingContext!)) {
        Navigator.pop(loadingContext!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Get urgent tasks for bell icon (Today's tasks + overdue tasks)
  List<Task> _getUrgentTasks() {
    final todayTasks = _tasksByStatus['TODAY'] ?? [];
    final now = DateTime.now();
    
    // Also include overdue tasks from upcoming
    final upcomingTasks = _tasksByStatus['UPCOMING'] ?? [];
    final overdueTasks = upcomingTasks.where((task) => 
      !task.isCompleted && task.dueDate.isBefore(now)
    ).toList();
    
    return [...todayTasks, ...overdueTasks];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final urgentTasks = _getUrgentTasks();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearchBar(),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () => _showUrgentTasksDialog(urgentTasks),
              ),
              if (urgentTasks.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      urgentTasks.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: _searchQuery.isNotEmpty ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E), size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ) : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        color: const Color(0xFF1A237E),
        backgroundColor: Colors.white,
        child: CustomScrollView(
          slivers: [
            // Status Tabs with Counts
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildStatusTab(0, 'Today', _tasksByStatus['TODAY']?.length ?? 0),
                    _buildStatusTab(1, 'Upcoming', _tasksByStatus['UPCOMING']?.length ?? 0),
                    _buildStatusTab(2, 'Completed', _tasksByStatus['COMPLETED']?.length ?? 0),
                  ],
                ),
              ),
            ),

            // Filter Section with Icon and Add Category (only show in Today tab)
            if (_selectedStatusIndex == 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Filter Icon with Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isFilterVisible ? Icons.filter_alt_off : Icons.filter_alt,
                              color: const Color(0xFF1A237E),
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _isFilterVisible = !_isFilterVisible;
                              });
                            },
                          ),
                          if (_selectedTaskCategory != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Selected Category Display (if any)
                      if (_selectedTaskCategory != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getTaskCategoryColor(_selectedTaskCategory!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedTaskCategory!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _getTaskCategoryColor(_selectedTaskCategory!),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTaskCategory = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: _getTaskCategoryColor(_selectedTaskCategory!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Expanded(
                          child: Text(
                            'All Categories',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      
                      // Add Category Button
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: ElevatedButton.icon(
                          onPressed: _showAddCategoryDialog,
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Filter Panel (visible when filter icon is toggled and in Today tab)
            if (_isFilterVisible && _selectedStatusIndex == 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // "All Categories" option
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTaskCategory = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: _selectedTaskCategory == null
                                ? const Color(0xFF1A237E).withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedTaskCategory == null
                                  ? const Color(0xFF1A237E)
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.grid_view,
                                size: 18,
                                color: Color(0xFF1A237E),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'All Categories',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const Divider(height: 16),
                      
                      // Category List
                      ..._masterCategories.map((category) {
                        final isSelected = _selectedTaskCategory == category.name;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTaskCategory = isSelected ? null : category.name;
                              // Close filter panel after selection
                              _isFilterVisible = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _getTaskCategoryColor(category.name).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _getTaskCategoryColor(category.name),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected
                                          ? _getTaskCategoryColor(category.name)
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            // Task List
            _buildTaskListSliver(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        backgroundColor: const Color(0xFF1A237E),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showUrgentTasksDialog(List<Task> urgentTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Urgent Tasks (${urgentTasks.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
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
                          Icon(Icons.check_circle, size: 48, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No urgent tasks!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: urgentTasks.length,
                      itemBuilder: (context, index) {
                        final task = urgentTasks[index];
                        final isOverdue = task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOverdue ? Icons.warning : Icons.notifications_active,
                                color: isOverdue ? Colors.red : Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              task.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOverdue 
                                          ? 'Overdue: ${DateFormat('MMM dd').format(task.dueDate)}'
                                          : 'Due: ${DateFormat('MMM dd').format(task.dueDate)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOverdue ? Colors.red : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showTaskDetails(task);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(int index, String label, int count) {
    final isSelected = _selectedStatusIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatusIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A237E) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchBar() {
    showSearch(
      context: context,
      delegate: TaskSearchDelegate(
        _tasks,
        onTaskSelected: (task) => _showTaskDetails(task),
        getTaskCategoryColor: _getTaskCategoryColor,
        getPriorityColor: _getPriorityColor,
        getPriorityIcon: _getPriorityIcon,
        formatDueDate: _formatDueDate,
      ),
    );
  }

  Widget _buildTaskListSliver() {
    if (_isLoadingTasks) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    List<Task> filteredTasks = _getFilteredTasks();

    if (filteredTasks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedTaskCategory == null
                      ? 'No ${_statusCategories[_selectedStatusIndex].toLowerCase()} tasks available'
                      : 'No tasks in $_selectedTaskCategory',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildTaskCard(filteredTasks[index]);
          },
          childCount: filteredTasks.length,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    
    final daysUntilDue = task.dueDate.difference(now).inDays;
    final isDueSoon = !task.isCompleted && daysUntilDue <= 2 && daysUntilDue >= 0;
    final isOverdue = !task.isCompleted && daysUntilDue < 0;
    final isToday = dueDateDay == today && !task.isCompleted;
    final isAlertSoon = task.alertDate != null && task.alertDate!.difference(now).inDays <= 3 && task.alertDate!.difference(now).inDays >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue 
              ? Colors.red.withOpacity(0.3)
              : (isDueSoon ? Colors.orange.withOpacity(0.3) : Colors.grey[200]!),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted 
                            ? Colors.grey 
                            : (isOverdue ? Colors.red[700] : Colors.black87),
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                  if (isOverdue)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Overdue',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Description with horizontal scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Tags Row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTaskCategoryColor(task.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getTaskCategoryColor(task.category),
                      ),
                    ),
                  ),
                  
                  // Priority
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPriorityIcon(task.priority),
                          size: 10,
                          color: _getPriorityColor(task.priority),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          task.priority.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getPriorityColor(task.priority),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Due Date
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue 
                          ? Colors.red.withOpacity(0.1)
                          : (isDueSoon ? Colors.orange.withOpacity(0.1) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 10,
                          color: isOverdue 
                              ? Colors.red
                              : (isDueSoon ? Colors.orange : Colors.grey[600]),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDueDate(task.dueDate),
                          style: TextStyle(
                            fontSize: 9,
                            color: isOverdue 
                                ? Colors.red
                                : (isDueSoon ? Colors.orange : Colors.grey[600]),
                            fontWeight: isOverdue || isDueSoon ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (task.alertDate != null && isAlertSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        size: 10,
                        color: Colors.orange,
                      ),
                    ),
                  
                  if (task.repeatPattern != RepeatPattern.Never)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.repeat,
                        size: 10,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRepeatPatternText(RepeatPattern pattern) {
    switch (pattern) {
      case RepeatPattern.Never:
        return '';
      case RepeatPattern.Daily:
        return 'Daily';
      case RepeatPattern.Weekly:
        return 'Weekly';
      case RepeatPattern.Monthly:
        return 'Monthly';
      case RepeatPattern.HalfYearly:
        return 'Half-Yearly';
      case RepeatPattern.Quarterly:
        return 'Quarterly';
      case RepeatPattern.Yearly:
        return 'Yearly';
      case RepeatPattern.Custom:
        return 'Custom';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  IconData _getPriorityIcon(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Icons.warning_amber_rounded;
      case Priority.medium:
        return Icons.info_outline;
      case Priority.low:
        return Icons.check_circle_outline;
    }
  }

  Color _getTaskCategoryColor(String category) {
    final hash = category.hashCode;
    final hue = hash.abs() % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.5).toColor();
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    if (dueDateDay == today) {
      return 'Today';
    } else if (dueDateDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM dd').format(dueDate);
    }
  }

  List<Task> _getFilteredTasks() {
    String currentStatus = _statusCategories[_selectedStatusIndex];
    
    List<Task> statusTasks = [];
    if (currentStatus == 'Today') {
      statusTasks = _tasksByStatus['TODAY'] ?? [];
    } else if (currentStatus == 'Upcoming') {
      statusTasks = _tasksByStatus['UPCOMING'] ?? [];
    } else if (currentStatus == 'Completed') {
      statusTasks = _tasksByStatus['COMPLETED'] ?? [];
    }
    
    // Apply category filter
    if (_selectedTaskCategory != null) {
      statusTasks = statusTasks.where((task) => task.category == _selectedTaskCategory).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      statusTasks = statusTasks.where((task) {
        return task.title.toLowerCase().contains(query) ||
               task.description.toLowerCase().contains(query) ||
               task.category.toLowerCase().contains(query);
      }).toList();
    }
    
    return statusTasks;
  }

  int _getCompletedCount() {
    return _tasksByStatus['COMPLETED']?.length ?? 0;
  }

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
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return const Center(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading categories...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final cachedData = await MyTasksService.getCachedMasterCategories();
      if (cachedData != null) {
        if (mounted && dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }
        if (mounted) {
          _processCategoriesResponse(cachedData);
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            if (_masterCategories.isEmpty) {
              _showNoCategoriesDialog();
            } else {
              _showCategorySelectionDialog();
            }
          }
        }
        return;
      }

      try {
        final response = await MyTasksService.getMasterCategories();
        
        if (mounted && dialogContext != null && Navigator.canPop(dialogContext!)) {
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
        return;
      } catch (e) {
        debugPrint('Failed to fetch master categories: $e');
        if (mounted && dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }
        if (mounted) {
          _showConnectionErrorDialog();
        }
      }
    } catch (e) {
      debugPrint('Error loading master categories: $e');
      if (mounted && dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      if (mounted) {
        _showConnectionErrorDialog();
      }
    }
  }

  void _showConnectionErrorDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Connection Error',
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
          ),
          content: const Text('Unable to connect to the server. Please check your connection and try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadMasterCategoriesForDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showNoCategoriesDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'No Categories',
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
          ),
          content: const Text('No task categories found. Would you like to add one?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showAddCategoryDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Category'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    if (!mounted) return;
    
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    bool isActive = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add New Category',
                style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g., Asset Maintenance',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(color: Color(0xFF1A237E), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    enabled: !isSaving,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(color: Color(0xFF1A237E), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    enabled: !isSaving,
                    maxLines: 2,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final categoryName = categoryController.text.trim();
                          if (categoryName.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a category name'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          try {
                            final response = await MyTasksService.saveMasterCategory(
                              name: categoryName,
                              description: descriptionController.text.trim().isEmpty 
                                  ? null 
                                  : descriptionController.text.trim(),
                              isActive: isActive,
                            );

                            if (response['success'] == true) {
                              await MyTasksService.clearMasterCategoriesCache();
                              final updatedCategories = await MyTasksService.getMasterCategories();
                              
                              if (mounted) {
                                Navigator.pop(ctx);
                                _processCategoriesResponse(updatedCategories);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Category "$categoryName" added'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              throw Exception(response['message'] ?? 'Failed to save category');
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => isSaving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isSaving ? 'Saving...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
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
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Category',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Add Category button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddCategoryDialog();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Color(0xFF1A237E), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Create New Category',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(),
                
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _masterCategories.length,
                    itemBuilder: (context, index) {
                      final category = _masterCategories[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getTaskCategoryColor(category.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(ctx);
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) {
                                _showAddTaskDialog(category);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(MasterCategory category) {
    if (!mounted) return;
    
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    DateTime? alertDate;
    DateTime? endDate;
    Priority selectedPriority = Priority.medium;
    RepeatPattern selectedRepeatPattern = RepeatPattern.Never;
    int customRepeatDays = 1;
    
    // Speech recognition
    stt.SpeechToText? speech;
    bool isListening = false;
    
    final pageContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            speech ??= stt.SpeechToText();
            
            void listen() async {
              if (!isListening) {
                bool available = await speech!.initialize();
                if (available) {
                  setDialogState(() => isListening = true);
                  speech!.listen(
                    onResult: (val) {
                      setDialogState(() {
                        descriptionController.text = val.recognizedWords;
                        descriptionController.selection = TextSelection.fromPosition(
                          TextPosition(offset: descriptionController.text.length)
                        );
                      });
                    },
                  );
                }
              } else {
                setDialogState(() => isListening = false);
                speech!.stop();
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Container(
                width: 500,
                constraints: const BoxConstraints(maxHeight: 600),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getTaskCategoryColor(category.name).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.task_alt,
                                color: _getTaskCategoryColor(category.name),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'New Task',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (isListening) speech?.stop();
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.close, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      const SizedBox(height: 16),
                      
                      // Title Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            hintText: 'Task Title',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Description with mic
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(ctx).size.width * 0.3,
                                  ),
                                  child: TextField(
                                    controller: descriptionController,
                                    decoration: const InputDecoration(
                                      hintText: 'Description',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    maxLines: null,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isListening ? Icons.mic : Icons.mic_none,
                                color: isListening ? Colors.red : const Color(0xFF1A237E),
                              ),
                              onPressed: listen,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Date Fields
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            // Due Date
                            _buildSimpleDatePicker(
                              context: dialogContext,
                              label: 'Due Date',
                              date: selectedDate,
                              icon: Icons.calendar_today,
                              onTap: () async {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate.isBefore(today) ? today : selectedDate,
                                  firstDate: today,
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color(0xFF1A237E),
                                      colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E)),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                            ),
                            
                            const Divider(height: 16),
                            
                            // Alert Date
                            _buildSimpleOptionalDatePicker(
                              context: dialogContext,
                              label: 'Set Alert',
                              date: alertDate,
                              icon: Icons.notifications_active,
                              color: Colors.orange,
                              onTap: () async {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: alertDate ?? (selectedDate.isBefore(today) ? today : selectedDate),
                                  firstDate: today,
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color(0xFF1A237E),
                                      colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E)),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setDialogState(() => alertDate = picked);
                                }
                              },
                              onClear: () => setDialogState(() => alertDate = null),
                            ),
                            
                            const Divider(height: 16),
                            
                            // End Date
                            _buildSimpleOptionalDatePicker(
                              context: dialogContext,
                              label: 'Alert End Date',
                              date: endDate,
                              icon: Icons.event,
                              color: Colors.blue,
                              onTap: () async {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: endDate ?? selectedDate,
                                  firstDate: selectedDate.isBefore(today) ? today : selectedDate,
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color(0xFF1A237E),
                                      colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E)),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setDialogState(() => endDate = picked);
                                }
                              },
                              onClear: () => setDialogState(() => endDate = null),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Repeat Pattern
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.repeat, color: Colors.green[600]),
                          title: Text(
                            selectedRepeatPattern == RepeatPattern.Never
                                ? 'Repeat'
                                : selectedRepeatPattern == RepeatPattern.Custom
                                    ? 'Every $customRepeatDays days'
                                    : _getRepeatPatternText(selectedRepeatPattern),
                          ),
                          trailing: selectedRepeatPattern != RepeatPattern.Never
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setDialogState(() {
                                    selectedRepeatPattern = RepeatPattern.Never;
                                    customRepeatDays = 1;
                                  }),
                                )
                              : const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _showSimpleRepeatDialog(
                            dialogContext, 
                            setDialogState, 
                            selectedRepeatPattern, 
                            (pattern, days) {
                              setDialogState(() {
                                selectedRepeatPattern = pattern;
                                if (pattern == RepeatPattern.Custom && days != null) {
                                  customRepeatDays = days;
                                }
                              });
                            }
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Priority
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: Priority.values.map((priority) {
                            final isSelected = selectedPriority == priority;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedPriority = priority),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _getPriorityColor(priority).withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? _getPriorityColor(priority) : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getPriorityIcon(priority),
                                        size: 14,
                                        color: isSelected ? _getPriorityColor(priority) : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        priority.toString().split('.').last,
                                        style: TextStyle(
                                          color: isSelected ? _getPriorityColor(priority) : Colors.grey,
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (isListening) speech?.stop();
                                Navigator.pop(ctx);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(color: Color(0xFF1A237E)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isListening) speech?.stop();
                                
                                if (titleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter task title'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                // Validate due date is not in past
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final selectedDateDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                                
                                if (selectedDateDay.isBefore(today)) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Due date cannot be in the past'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final taskTitle = titleController.text.trim();
                                final taskDescription = descriptionController.text.trim();
                                final taskDueDate = selectedDate;
                                final taskAlertDate = alertDate;
                                final taskEndDate = endDate;
                                final taskPriority = selectedPriority;
                                final taskCategory = category;
                                final taskRepeatPattern = selectedRepeatPattern;
                                final taskCustomRepeatDays = customRepeatDays;
                                
                                Navigator.pop(ctx);
                                await Future.delayed(const Duration(milliseconds: 150));
                                
                                if (!mounted) return;
                                
                                BuildContext? loadingContext;
                                showDialog(
                                  context: pageContext,
                                  barrierDismissible: false,
                                  builder: (ctx) {
                                    loadingContext = ctx;
                                    return const Center(
                                      child: Dialog(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('Saving...'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );

                                try {
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final taskDay = DateTime(taskDueDate.year, taskDueDate.month, taskDueDate.day);
                                  final taskStatus = taskDay == today ? 'TODAY' : 'UPCOMING';
                                  final categoryId = int.tryParse(taskCategory.id) ?? 0;
                                  
                                  // Format dates for API
                                  final formattedReminderDatetime = taskAlertDate != null 
                                      ? DateFormat("yyyy-MM-dd'T'00:00:00").format(taskAlertDate)
                                      : null;
                                  
                                  final formattedEndDate = taskEndDate != null
                                      ? DateFormat("yyyy-MM-dd'T'00:00:00").format(taskEndDate)
                                      : null;
                                  
                                  // Map repeat pattern to API expected values
                                  String? repeatType;
                                  String? repeatUnit;
                                  int? repeatInterval;
                                  
                                  switch (taskRepeatPattern) {
                                    case RepeatPattern.Daily:
                                      repeatType = 'DAILY';
                                      repeatUnit = 'DAY';
                                      repeatInterval = 1;
                                      break;
                                    case RepeatPattern.Weekly:
                                      repeatType = 'WEEKLY';
                                      repeatUnit = 'WEEK';
                                      repeatInterval = 1;
                                      break;
                                    case RepeatPattern.Monthly:
                                      repeatType = 'MONTHLY';
                                      repeatUnit = 'MONTH';
                                      repeatInterval = 1;
                                      break;
                                    case RepeatPattern.Quarterly:
                                      repeatType = 'QUARTERLY';
                                      repeatUnit = 'MONTH';
                                      repeatInterval = 3;
                                      break;
                                    case RepeatPattern.HalfYearly:
                                      repeatType = 'HALF_YEARLY';
                                      repeatUnit = 'MONTH';
                                      repeatInterval = 6;
                                      break;
                                    case RepeatPattern.Yearly:
                                      repeatType = 'YEARLY';
                                      repeatUnit = 'YEAR';
                                      repeatInterval = 1;
                                      break;
                                    case RepeatPattern.Custom:
                                      repeatType = 'CUSTOM';
                                      repeatUnit = 'DAY';
                                      repeatInterval = taskCustomRepeatDays;
                                      break;
                                    case RepeatPattern.Never:
                                      repeatType = null;
                                      repeatUnit = null;
                                      repeatInterval = null;
                                      break;
                                  }
                               
                                  final response = await MyTasksService.saveTask(
                                    roleGroupName: 'Admin',
                                    taskCategoryId: categoryId,
                                    taskName: taskTitle,
                                    description: taskDescription,
                                    status: taskStatus,
                                    priority: taskPriority.toString().split('.').last.toUpperCase(),
                                    reminderDatetime: formattedReminderDatetime,
                                    repeatType: repeatType,
                                    repeatInterval: repeatInterval,
                                    repeatUnit: repeatUnit,
                                    repeatEndDate: formattedEndDate,
                                  );

                                  if (loadingContext != null && Navigator.canPop(loadingContext!)) {
                                    Navigator.pop(loadingContext!);
                                  }

                                  if (!mounted) return;
                                  
                                  if (response['status_code'] == 200 || response['status_code'] == 201 || response['success'] == true) {
                                    final newTask = Task(
                                      realId: response['taskId'], 
                                      title: taskTitle,
                                      description: taskDescription,
                                      dueDate: taskDueDate,
                                      alertDate: taskAlertDate,
                                      endDate: taskEndDate,
                                      repeatPattern: taskRepeatPattern,
                                      customRepeatDays: taskCustomRepeatDays,
                                      priority: taskPriority,
                                      isCompleted: false,
                                      status: taskStatus.toLowerCase(),
                                      category: taskCategory.name,
                                    );
                                    
                                    setState(() {
                                      if (taskStatus == 'TODAY') {
                                        _tasksByStatus['TODAY']?.add(newTask);
                                      } else {
                                        _tasksByStatus['UPCOMING']?.add(newTask);
                                      }
                                      // Don't set category filter automatically
                                      _mergeAllTasks();
                                    });

                                    ScaffoldMessenger.of(pageContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('Task added'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    throw Exception(response['message'] ?? 'Failed to save task');
                                  }
                                } catch (e) {
                                  if (loadingContext != null && Navigator.canPop(loadingContext!)) {
                                    Navigator.pop(loadingContext!);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(pageContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Save', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleDatePicker({
    required BuildContext context,
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Spacer(),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleOptionalDatePicker({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: date != null ? color : Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: date != null ? color : Colors.grey[600]),
            ),
            const Spacer(),
            if (date != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  ),
                ],
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSimpleRepeatDialog(
    BuildContext context, 
    StateSetter setState, 
    RepeatPattern current, 
    Function(RepeatPattern, int?) onSelected
  ) {
    int customDays = 1;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Repeat', style: TextStyle(color: Color(0xFF1A237E))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...RepeatPattern.values.map((pattern) {
                if (pattern == RepeatPattern.Custom) {
                  return ListTile(
                    title: const Text('Custom'),
                    leading: Radio<RepeatPattern>(
                      value: pattern,
                      groupValue: current,
                      onChanged: (value) {
                        Navigator.pop(ctx);
                        _showCustomDaysDialog(context, (days) {
                          onSelected(value!, days);
                        });
                      },
                    ),
                  );
                }
                return ListTile(
                  title: Text(pattern == RepeatPattern.Never 
                      ? 'Never' 
                      : pattern.toString().split('.').last),
                  leading: Radio<RepeatPattern>(
                    value: pattern,
                    groupValue: current,
                    onChanged: (value) {
                      Navigator.pop(ctx);
                      if (value != null) onSelected(value, null);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomDaysDialog(BuildContext context, Function(int) onSelected) {
    int days = 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Repeat', style: TextStyle(color: Color(0xFF1A237E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Repeat every'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Days',
                    ),
                    onChanged: (value) => days = int.tryParse(value) ?? 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('days'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSelected(days);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
            ),
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Task Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTaskCategoryColor(task.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(task.category, style: TextStyle(color: _getTaskCategoryColor(task.category), fontSize: 12)),
              ),
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              // Description with horizontal scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(task.description, style: const TextStyle(color: Colors.black54)),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Due Date', DateFormat('MMM dd, yyyy').format(task.dueDate), Icons.calendar_today),
              if (task.alertDate != null) _buildDetailRow('Alert', DateFormat('MMM dd, yyyy').format(task.alertDate!), Icons.notifications_active, color: Colors.orange),
              if (task.endDate != null) _buildDetailRow(' Alert End Date', DateFormat('MMM dd, yyyy').format(task.endDate!), Icons.event, color: Colors.blue),
              if (task.repeatPattern != RepeatPattern.Never) 
                _buildDetailRow('Repeat', 
                  task.repeatPattern == RepeatPattern.Custom 
                      ? 'Every ${task.customRepeatDays} days' 
                      : task.repeatPattern == RepeatPattern.HalfYearly
                          ? 'Half-Yearly'
                          : task.repeatPattern == RepeatPattern.Quarterly
                              ? 'Quarterly'
                              : task.repeatPattern.toString().split('.').last, 
                  Icons.repeat, 
                  color: Colors.green),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: task.realId == null ? null : () {
                        _updateTaskStatus(task, !task.isCompleted);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: task.isCompleted ? Colors.grey : const Color(0xFF1A237E),
                      ),
                      child: Text(task.realId == null ? 'Cannot Update' : (task.isCompleted ? 'Mark Pending' : 'Mark Complete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color color = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(value, style: TextStyle(color: color)),
            ),
          ),
        ],
      ),
    );
  }

  void _searchTasks(BuildContext context) => _showSearchBar();
  void _onTaskSelected(Task task) => _showTaskDetails(task);
}

enum Priority { high, medium, low }
enum RepeatPattern { Never, Daily, Weekly, Monthly, HalfYearly, Quarterly, Yearly, Custom }

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

  Task({
    this.realId, 
    required this.title,
    required this.description,
    required this.dueDate,
    this.alertDate,
    this.endDate,
    this.repeatPattern = RepeatPattern.Never,
    this.customRepeatDays = 1,
    required this.priority,
    required this.isCompleted,
    required this.status,
    required this.category,
  });

  factory Task.fromJson(Map<String, dynamic> json, String statusFromApi) {
    DateTime dueDate;
    if (json['dueDate'] != null) {
      dueDate = DateTime.parse(json['dueDate'].toString());
    } else if (json['taskDate'] != null) {
      dueDate = DateTime.parse(json['taskDate'].toString());
    } else {
      dueDate = DateTime.now();
    }

    DateTime? alertDate;
    if (json['alertDate'] != null) {
      try {
        alertDate = DateTime.parse(json['alertDate'].toString());
      } catch (e) {}
    }

    DateTime? endDate;
    if (json['endDate'] != null) {
      try {
        endDate = DateTime.parse(json['endDate'].toString());
      } catch (e) {}
    }

    RepeatPattern repeatPattern = RepeatPattern.Never;
    if (json['repeatPattern'] != null) {
      final patternStr = json['repeatPattern'].toString().toLowerCase();
      if (patternStr.contains('daily')) repeatPattern = RepeatPattern.Daily;
      else if (patternStr.contains('weekly')) repeatPattern = RepeatPattern.Weekly;
      else if (patternStr.contains('monthly')) repeatPattern = RepeatPattern.Monthly;
      else if (patternStr.contains('half') || patternStr.contains('half-yearly')) repeatPattern = RepeatPattern.HalfYearly;
      else if (patternStr.contains('quarter')) repeatPattern = RepeatPattern.Quarterly;
      else if (patternStr.contains('yearly')) repeatPattern = RepeatPattern.Yearly;
      else if (patternStr.contains('custom')) repeatPattern = RepeatPattern.Custom;
    }

    int customRepeatDays = json['customRepeatDays'] ?? 1;

    Priority priority = Priority.medium;
    final priorityStr = json['priority']?.toString().toLowerCase() ?? '';
    if (priorityStr.contains('high')) priority = Priority.high;
    else if (priorityStr.contains('low')) priority = Priority.low;

    bool isCompleted = statusFromApi == 'COMPLETED' || json['status']?.toString().toLowerCase() == 'completed' || json['isCompleted'] == true;
    String status = statusFromApi.toLowerCase();

    int? realId;
    if (json['id'] != null && json['id'].toString().isNotEmpty && json['id'].toString() != 'null') {
      realId = int.tryParse(json['id'].toString());
    } else if (json['taskId'] != null && json['taskId'].toString().isNotEmpty) {
      realId = int.tryParse(json['taskId'].toString());
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
      status: status,
      category: json['categoryName'] ?? json['category'] ?? 'General',
    );
  }
}

class MasterCategory {
  final String id;
  final String name;
  final String? description;
  final String? code;
  final bool isActive;

  MasterCategory({
    required this.id,
    required this.name,
    this.description,
    this.code,
    required this.isActive,
  });

  factory MasterCategory.fromJson(Map<String, dynamic> json) {
    return MasterCategory(
      id: json['id']?.toString() ?? json['categoryId']?.toString() ?? '',
      name: json['name'] ?? json['categoryName'] ?? '',
      description: json['description'],
      code: json['code'],
      isActive: json['isActive'] ?? json['active'] ?? true,
    );
  }
}

class TaskSearchDelegate extends SearchDelegate<Task?> {
  final List<Task> tasks;
  final Function(Task)? onTaskSelected;
  final Color Function(String) getTaskCategoryColor;
  final Color Function(Priority) getPriorityColor;
  final IconData Function(Priority) getPriorityIcon;
  final String Function(DateTime) formatDueDate;

  TaskSearchDelegate(
    this.tasks, {
    this.onTaskSelected,
    required this.getTaskCategoryColor,
    required this.getPriorityColor,
    required this.getPriorityIcon,
    required this.formatDueDate,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Color(0xFF1A237E)),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<Task> filteredTasks = _filterTasks(query);

    if (filteredTasks.isEmpty) {
      return _buildNoResults(context);
    }

    return _buildSearchResults(filteredTasks, context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<Task> filteredTasks = _filterTasks(query);

    if (query.isEmpty) {
      return _buildRecentSearches(context);
    }

    if (filteredTasks.isEmpty) {
      return _buildNoResults(context);
    }

    return _buildSearchSuggestions(filteredTasks);
  }

  List<Task> _filterTasks(String searchQuery) {
    if (searchQuery.isEmpty) return [];

    final lowercaseQuery = searchQuery.toLowerCase();
    return tasks.where((task) {
      return task.title.toLowerCase().contains(lowercaseQuery) ||
          task.description.toLowerCase().contains(lowercaseQuery) ||
          task.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Widget _buildSearchResults(List<Task> filteredTasks, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildSearchResultCard(task, context);
      },
    );
  }

  Widget _buildSearchSuggestions(List<Task> filteredTasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildSuggestionItem(task, context);
      },
    );
  }

  Widget _buildSearchResultCard(Task task, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final isToday = dueDateDay == today && !task.isCompleted;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isCompleted ? Colors.green.withOpacity(0.3) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: RichText(
          text: TextSpan(
            children: _highlightText(task.title, query),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: task.isCompleted ? Colors.grey : Colors.black87,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Description with horizontal scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: getTaskCategoryColor(task.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: getTaskCategoryColor(task.category),
                    ),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatDueDate(task.dueDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getPriorityColor(task.priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            task.priority.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: getPriorityColor(task.priority),
            ),
          ),
        ),
        onTap: () {
          if (onTaskSelected != null) {
            onTaskSelected!(task);
          }
          close(context, task);
        },
      ),
    );
  }

  Widget _buildSuggestionItem(Task task, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.search, color: Color(0xFF1A237E), size: 20),
      title: RichText(
        text: TextSpan(
          children: _highlightText(task.title, query),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: getTaskCategoryColor(task.category).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          task.category,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: getTaskCategoryColor(task.category),
          ),
        ),
      ),
      onTap: () {
        query = task.title;
        showResults(context);
      },
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.history, color: Colors.grey),
          title: Text('patient rounds'),
        ),
        ListTile(
          leading: Icon(Icons.history, color: Colors.grey),
          title: Text('medication'),
        ),
      ],
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final pattern = RegExp(query, caseSensitive: false);
    final matches = pattern.allMatches(text);

    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(
          backgroundColor: Color(0xFF1A237E),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }

    return spans;
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1A237E)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.only(left: 16),
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search tasks...';
}