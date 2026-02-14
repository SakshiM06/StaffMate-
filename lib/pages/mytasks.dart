import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_mate/services/my_tasks_service.dart';

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
  }

  Future<void> _loadAllTasks() async {
    setState(() {
      _isLoadingTasks = true;
    });
    
    debugPrint('=== LOAD ALL TASKS ===');
    
    try {
      await Future.wait([
        _fetchTasksByStatus('TODAY'),
        _fetchTasksByStatus('UPCOMING'),
        _fetchTasksByStatus('COMPLETED'),
      ]);
      
      _mergeAllTasks();
      
      debugPrint('Tasks loaded - Today: ${_tasksByStatus['TODAY']?.length ?? 0}, '
                 'Upcoming: ${_tasksByStatus['UPCOMING']?.length ?? 0}, '
                 'Completed: ${_tasksByStatus['COMPLETED']?.length ?? 0}');
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
        debugPrint('Using cached tasks for status: $status');
        _processTasksResponse(cachedData, status);
        return;
      }

      debugPrint('Fetching tasks for status: $status');
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
    debugPrint('=== PROCESS TASKS RESPONSE FOR STATUS: $status ===');
    
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
    
    debugPrint('Found ${tasksData.length} tasks for status: $status');
    
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
        
        debugPrint('Successfully processed ${tasks.length} valid tasks');
        _tasksByStatus[status] = tasks;
      });
    }
  }

  void _mergeAllTasks() {
    final allTasks = <Task>[];
    
    _tasksByStatus.forEach((status, tasks) {
      allTasks.addAll(tasks);
    });
    
    setState(() {
      _tasks.clear();
      _tasks.addAll(allTasks);
    });
  }

  Future<void> _loadMasterCategories() async {
    if (!mounted) return;

    debugPrint('=== LOAD MASTER CATEGORIES ===');
    
    try {
      final cachedData = await MyTasksService.getCachedMasterCategories();
      if (cachedData != null && mounted) {
        debugPrint('Using cached master categories');
        _processCategoriesResponse(cachedData);
        return;
      }

      try {
        debugPrint('Attempting to fetch master categories...');
        final response = await MyTasksService.getMasterCategories();
        debugPrint('Response received: $response');
        
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load categories. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    debugPrint('=== PROCESS CATEGORIES RESPONSE ===');
    
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
        debugPrint('Processed ${_masterCategories.length} master categories');
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
      
      debugPrint('=== UPDATE TASK STATUS ===');
      debugPrint('Task ID from backend: ${task.realId}');
      debugPrint('New Status: $newStatus');
      
      final response = await MyTasksService.updateTaskStatus(
        taskId: task.realId!,
        status: newStatus,
      );
      if (mounted && loadingContext != null && Navigator.canPop(loadingContext!)) {
        Navigator.pop(loadingContext!);
      }

      if (response['success'] == true) {
        debugPrint('✅ Task status updated successfully');
        
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _searchTasks(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshTasks,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        color: const Color(0xFF1A237E),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: List.generate(
                  _statusCategories.length,
                  (index) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatusIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedStatusIndex == index
                              ? const Color(0xFF1A237E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            _statusCategories[index],
                            style: TextStyle(
                              color: _selectedStatusIndex == index 
                                  ? Colors.white 
                                  : Colors.grey[600],
                              fontWeight: _selectedStatusIndex == index 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            if (_selectedTaskCategory != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getTaskCategoryColor(_selectedTaskCategory!).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getTaskCategoryColor(_selectedTaskCategory!),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getTaskCategoryColor(_selectedTaskCategory!),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedTaskCategory!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getTaskCategoryColor(_selectedTaskCategory!),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
                              size: 14,
                              color: _getTaskCategoryColor(_selectedTaskCategory!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_getFilteredTasks().length} Tasks',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_getCompletedCount()} Completed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildTaskList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewTask,
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    if (_isLoadingTasks) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    List<Task> filteredTasks = _getFilteredTasks();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedTaskCategory == null
                    ? 'No ${_statusCategories[_selectedStatusIndex].toLowerCase()} tasks available'
                    : 'No $_selectedTaskCategory tasks in ${_statusCategories[_selectedStatusIndex].toLowerCase()}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(filteredTasks[index]);
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isCompleted 
              ? Colors.green.withValues(alpha: 0.3) 
              : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        color: task.isCompleted ? Colors.grey : Colors.black87,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (task.status == 'today' && !task.isCompleted)
                    const SizedBox(width: 8),
                  if (task.status == 'today' && !task.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTaskCategoryColor(task.category).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _getTaskCategoryColor(task.category),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getPriorityIcon(task.priority),
                            size: 12,
                            color: _getPriorityColor(task.priority),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.priority.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getPriorityColor(task.priority),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDueDate(task.dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.5).toColor();
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
      return DateFormat('MMM dd, yyyy').format(dueDate);
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
    
    if (_selectedTaskCategory != null) {
      return statusTasks.where((task) => task.category == _selectedTaskCategory).toList();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Connection Error',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Unable to connect to the server. Please check your connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadMasterCategoriesForDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'No Categories',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'No task categories found in the system. Please contact your administrator.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showCategorySelectionDialog() {
    if (!mounted) return;
    if (_masterCategories.isEmpty) {
      _showNoCategoriesDialog();
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 600),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a category for your new task',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _masterCategories.length,
                    itemBuilder: (context, index) {
                      final category = _masterCategories[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (mounted) {
                                  _showAddTaskDialog(category);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getTaskCategoryColor(category.name),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        if (category.description != null && category.description!.isNotEmpty)
                                          Text(
                                            category.description!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
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
    Priority selectedPriority = Priority.medium;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              child: Container(
                width: 450,
                constraints: const BoxConstraints(maxHeight: 550),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add New Task',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getTaskCategoryColor(category.name),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getTaskCategoryColor(category.name),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.close, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          hintText: 'e.g., Morning Patient Rounds',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1A237E), width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
             
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Brief description of the task...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1A237E), width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 2,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  primaryColor: const Color(0xFF1A237E),
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF1A237E),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null && mounted) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'Due Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Priority',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: Priority.values.map((priority) {
                                bool isSelected = selectedPriority == priority;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPriority = priority;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _getPriorityColor(priority).withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? _getPriorityColor(priority)
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getPriorityIcon(priority),
                                            size: 14,
                                            color: isSelected
                                                ? _getPriorityColor(priority)
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              priority.toString().split('.').last,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? _getPriorityColor(priority)
                                                    : Colors.grey,
                                                fontWeight: isSelected 
                                                    ? FontWeight.w600 
                                                    : FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
               
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
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

                                final taskTitle = titleController.text.trim();
                                final taskDescription = descriptionController.text.trim();
                                final taskDueDate = selectedDate;
                                final taskPriority = selectedPriority;
                                final taskCategory = category;
                                
                                debugPrint('=== ADD NEW TASK ===');
                                debugPrint('Category: ${taskCategory.name} (ID: ${taskCategory.id})');
                                
                                Navigator.pop(ctx);
                                
                                await Future.delayed(const Duration(milliseconds: 100));
                                
                                if (!mounted) return;
                                
                                BuildContext? loadingContext;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext dialogCtx) {
                                    loadingContext = dialogCtx;
                                    return const Center(
                                      child: Dialog(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('Saving task...'),
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
                                  
                                  debugPrint('Saving task with category ID: $categoryId');
                                  debugPrint('Status: $taskStatus');
                               
                                  final response = await MyTasksService.saveTask(
                                    roleGroupName: 'Admin',
                                    taskCategoryId: categoryId,
                                    taskName: taskTitle,
                                    description: taskDescription,
                                    status: taskStatus,
                                    priority: taskPriority.toString().split('.').last.toUpperCase(),
                                  );

                                  debugPrint('=== SAVE TASK RESPONSE ===');
                                  debugPrint('Status Code: ${response['status_code']}');
                                  debugPrint('Message: ${response['message']}');
                                  debugPrint('Task ID from save API: ${response['taskId']}');

                                  if (mounted && loadingContext != null) {
                                    if (Navigator.canPop(loadingContext!)) {
                                      Navigator.pop(loadingContext!);
                                    }
                                  }

                                  if (mounted) {
                                    bool isSuccess = response['status_code'] == 200 || 
                                                    response['status_code'] == 201 || 
                                                    response['success'] == true;
                                    
                                    if (isSuccess) {
                                      int? savedTaskId = response['taskId'];
                                      
                                      if (savedTaskId == null || savedTaskId <= 0) {
                                        debugPrint('⚠️ Warning: Save API did not return a valid task ID');
                                      } else {
                                        debugPrint('✅ Task saved successfully with ID: $savedTaskId');
                                      }
                                      
                                      final newTask = Task(
                                        realId: savedTaskId, 
                                        title: taskTitle,
                                        description: taskDescription,
                                        dueDate: taskDueDate,
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
                                        
                                        _selectedTaskCategory = taskCategory.name;
                                        _mergeAllTasks();
                                      });

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(savedTaskId != null && savedTaskId > 0 
                                              ? 'Task added successfully with ID: $savedTaskId'
                                              : 'Task added successfully'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      throw Exception(response['message'] ?? 'Failed to save task');
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('❌ Error saving task: $e');
                                  
                                  if (mounted && loadingContext != null) {
                                    if (Navigator.canPop(loadingContext!)) {
                                      Navigator.pop(loadingContext!);
                                    }
                                  }
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save task: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Save Task',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
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

  void _showTaskDetails(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Task Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTaskCategoryColor(task.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getTaskCategoryColor(task.category),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  task.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Due Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(task.dueDate),
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPriorityIcon(task.priority),
                        size: 14,
                        color: _getPriorityColor(task.priority),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        task.priority.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getPriorityColor(task.priority),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: task.realId == null 
                            ? null  
                            : () {
                                _updateTaskStatus(task, !task.isCompleted);
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: task.isCompleted ? Colors.grey : const Color(0xFF1A237E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Text(
                          task.realId == null 
                              ? 'Cannot Update (No ID)' 
                              : (task.isCompleted ? 'Mark Pending' : 'Mark Complete'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.realId != null && task.realId! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Task ID: ${task.realId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _searchTasks(BuildContext context) {
    showSearch(
      context: context,
      delegate: TaskSearchDelegate(
        _tasks,
        onTaskSelected: _onTaskSelected,
        getTaskCategoryColor: _getTaskCategoryColor,
        getPriorityColor: _getPriorityColor,
        getPriorityIcon: _getPriorityIcon,
        formatDueDate: _formatDueDate,
      ),
    );
  }

  void _onTaskSelected(Task task) {
    _showTaskDetails(task);
  }
}

enum Priority { high, medium, low }

class Task {
  final int? realId;  
  final String title;
  final String description;
  final DateTime dueDate;
  final Priority priority;
  bool isCompleted;
  String status;
  final String category;

  Task({
    this.realId, 
    required this.title,
    required this.description,
    required this.dueDate,
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

    Priority priority = Priority.medium;
    final priorityStr = json['priority']?.toString().toLowerCase() ?? '';
    if (priorityStr.contains('high')) {
      priority = Priority.high;
    } else if (priorityStr.contains('low')) {
      priority = Priority.low;
    }

    bool isCompleted = statusFromApi == 'COMPLETED' || 
                      json['status']?.toString().toLowerCase() == 'completed' ||
                      json['isCompleted'] == true;

    String status = statusFromApi.toLowerCase();

    int? realId;
    if (json['id'] != null && json['id'].toString().isNotEmpty && json['id'].toString() != 'null') {
      realId = int.tryParse(json['id'].toString());
    } else if (json['taskId'] != null && json['id'].toString().isNotEmpty) {
      realId = int.tryParse(json['taskId'].toString());
    }
    
    if (realId == null) {
      debugPrint('⚠️ WARNING: Task "${json['taskName']}" has no ID from backend!');
      debugPrint('⚠️ This task cannot be updated via API until backend provides ID');
    }
    int? categoryIdInt;
    if (json['taskCategoryId'] != null && json['taskCategoryId'].toString() != 'null') {
      categoryIdInt = int.tryParse(json['taskCategoryId'].toString());
    }

    return Task(
      realId: realId, 
      title: json['taskName'] ?? json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? json['discription'] ?? '',
      dueDate: dueDate,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isCompleted ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!,
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
            Text(
              task.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: getTaskCategoryColor(task.category).withValues(alpha: 0.1),
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
                  const SizedBox(width: 8),
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
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getPriorityColor(task.priority).withValues(alpha: 0.1),
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
          color: getTaskCategoryColor(task.category).withValues(alpha: 0.1),
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