import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyTasksService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://192.168.1.14:8089';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8089'; // Android emulator
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8089'; // iOS simulator
    } else {
      return 'http://192.168.1.14:8089'; // Your computer's IP
    }
  }
  
  static const String _physicalDeviceUrl = 'http://192.168.1.14:8089';
  
  static const String _masterCategoryEndpoint = '/master/category/master/getAll';
  static const String _saveTaskEndpoint = '/master/task/master/save';
  static const String _fetchTasksEndpoint = '/master/task/master/fetch';
  static const String _updateTaskEndpoint = '/master/task/master/update';

  static Future<Map<String, dynamic>> getAllMasterCategories() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (clinicId.isEmpty) throw Exception('Clinic ID missing');
      if (userId.isEmpty) throw Exception('User ID missing');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final url = '$_physicalDeviceUrl$_masterCategoryEndpoint';
      
      debugPrint('=== MASTER CATEGORY API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');

      final client = http.Client();
      
      try {
        final response = await client
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                client.close();
                throw Exception('Connection timeout. Server not responding at 192.168.1.14:8089');
              },
            );

        stopwatch.stop();
        debugPrint('=== MASTER CATEGORY API RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
      
          Map<String, dynamic> formattedResponse;
          
          if (decoded is List) {
            formattedResponse = {
              'data': decoded,
              'message': 'Success',
              'status_code': 200
            };
          } else if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('data')) {
              formattedResponse = decoded;
            } else {
              formattedResponse = {
                'data': [decoded],
                'message': 'Success',
                'status_code': 200
              };
            }
          } else {
            formattedResponse = {
              'data': [],
              'message': 'Unknown response format',
              'status_code': 200
            };
          }
     
          await _cacheMasterCategoriesResponse(formattedResponse);
          
          return formattedResponse;
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please login again.');
        } else if (response.statusCode == 403) {
          throw Exception('Access forbidden. Check your permissions.');
        } else {
          throw Exception('Server returned status code: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('MyTasksService Error (getAllMasterCategories): $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMasterCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final url = '$_physicalDeviceUrl$_masterCategoryEndpoint';
      
      debugPrint('=== GET MASTER CATEGORIES API REQUEST ===');
      debugPrint('URL: $url');
      debugPrint('Platform: ${Platform.operatingSystem}');

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        List<dynamic> categories = [];
        
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data')) {
            final dataObj = decoded['data'];
            if (dataObj is List) {
              categories = dataObj;
            } else if (dataObj is Map && dataObj.containsKey('list')) {
              categories = dataObj['list'] as List;
            }
          }
        } else if (decoded is List) {
          categories = decoded;
        }
        
        return {
          'data': categories,
          'message': 'Success',
          'status_code': 200
        };
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Check your permissions.');
      } else {
        throw Exception('Failed to fetch categories. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get master categories failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> saveTask({
    required String roleGroupName,
    required int taskCategoryId,
    required String taskName,
    required String description,
    required String status,
    required String priority,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (clinicId.isEmpty) throw Exception('Clinic ID missing');
      if (userId.isEmpty) throw Exception('User ID missing');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final url = '$_physicalDeviceUrl$_saveTaskEndpoint';
      
      final Map<String, dynamic> requestBody = {
        'roleGroupName': roleGroupName,
        'taskCategoryId': taskCategoryId,
        'taskName': taskName,
        'description': description,
        'discription': description,
        'status': status.toUpperCase(),
        'priority': priority.toUpperCase(),
      };

      debugPrint('=== SAVE TASK API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');

      final client = http.Client();
      
      try {
        final response = await client
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(requestBody),
            )
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () {
                client.close();
                throw Exception('Connection timeout. Please check if server is accessible at 192.168.1.14:8089');
              },
            );

        stopwatch.stop();
        debugPrint('=== SAVE TASK API RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Response Body: ${response.body}');
        if (response.statusCode == 500) {
          throw Exception('Internal Server Error: Database may be missing required columns');
        }

        if (response.statusCode == 400) {
          try {
            final errorResponse = jsonDecode(response.body);
            String errorMessage = 'Database error: ';
            if (errorResponse is Map) {
              if (errorResponse['message'] != null) {
                errorMessage = errorResponse['message'];
              }
              if (errorResponse['error'] != null) {
                final error = errorResponse['error'];
                if (error is Map && error['cause'] != null) {
                  errorMessage = error['cause'].toString();
                }
              }
            }
            throw Exception('$errorMessage. Please check backend database schema.');
          } catch (e) {
            throw Exception('Failed to save task. Database error occurred.');
          }
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please login again.');
        } else if (response.statusCode == 403) {
          throw Exception('Access forbidden. Check your permissions.');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
            final decoded = jsonDecode(response.body);
            int? taskId;
            if (decoded is Map<String, dynamic>) {
                            if (decoded.containsKey('data') && decoded['data'] is Map) {
                final data = decoded['data'] as Map;
                if (data.containsKey('id')) {
                  taskId = int.tryParse(data['id'].toString());
                }
              } else if (decoded.containsKey('id')) {
                taskId = int.tryParse(decoded['id'].toString());
              } else if (decoded.containsKey('taskId')) {
                taskId = int.tryParse(decoded['taskId'].toString());
              }
              
              debugPrint('✅ Task saved with ID: $taskId');
              
              return {
                'success': true,
                'message': 'Task saved successfully',
                'status_code': response.statusCode,
                'data': decoded,
                'taskId': taskId,
              };
            } else {
              return {
                'success': true,
                'message': 'Task saved successfully',
                'status_code': response.statusCode,
                'data': decoded,
                'taskId': null,
              };
            }
          } catch (e) {
            return {
              'success': true,
              'message': 'Task saved successfully',
              'status_code': response.statusCode,
              'taskId': null,
            };
          }
        } else {
          String errorMessage = 'Failed to save task (${response.statusCode})';
          try {
            final error = jsonDecode(response.body);
            if (error is Map) {
              if (error['message'] != null) {
                errorMessage = error['message'];
              } else if (error['error'] != null) {
                errorMessage = error['error'].toString();
              }
            }
          } catch (_) {}
          throw Exception(errorMessage);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('MyTasksService Error (saveTask): $e');
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> updateTaskStatus({
    required int taskId,
    required String status,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (clinicId.isEmpty) throw Exception('Clinic ID missing');
      if (userId.isEmpty) throw Exception('User ID missing');
      if (taskId <= 0) throw Exception('Invalid task ID: $taskId');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final url = '$_physicalDeviceUrl$_updateTaskEndpoint';
      final Map<String, dynamic> requestBody = {
        'id': taskId, 
        'status': status.toUpperCase(),
      };

      debugPrint('=== UPDATE TASK STATUS API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');
      debugPrint('IMPORTANT: "id" field is the TASK ID (from fetch API), not category ID');

      final client = http.Client();
      
      try {
        final response = await client
            .put(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(requestBody),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                client.close();
                throw Exception('Connection timeout. Please check if server is accessible at 192.168.1.14:8089');
              },
            );

        stopwatch.stop();
        debugPrint('=== UPDATE TASK STATUS API RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
            final decoded = jsonDecode(response.body);
            await clearTasksCache('TODAY');
            await clearTasksCache('UPCOMING');
            await clearTasksCache('COMPLETED');
            
            debugPrint('✅ Task status updated successfully');
            
            return {
              'success': true,
              'message': 'Task status updated successfully',
              'status_code': response.statusCode,
              'data': decoded,
            };
          } catch (e) {
            return {
              'success': true,
              'message': 'Task status updated successfully',
              'status_code': response.statusCode,
            };
          }
        } else if (response.statusCode == 400) {
          try {
            final errorResponse = jsonDecode(response.body);
            String errorMessage = 'Failed to update task: ';
            if (errorResponse is Map) {
              if (errorResponse['message'] != null) {
                errorMessage = errorResponse['message'];
              }
            }
            throw Exception(errorMessage);
          } catch (e) {
            throw Exception('Failed to update task status. Task ID: $taskId may not exist in database.');
          }
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please login again.');
        } else if (response.statusCode == 403) {
          throw Exception('Access forbidden. Check your permissions.');
        } else if (response.statusCode == 404) {
          throw Exception('Task not found with ID: $taskId. This task may not exist in the database.');
        } else {
          throw Exception('Server returned status code: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('MyTasksService Error (updateTaskStatus): $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> markTaskAsCompleted(int taskId) async {
    return updateTaskStatus(
      taskId: taskId,
      status: 'COMPLETED',
    );
  }
  static Future<Map<String, dynamic>> markTaskAsPending(int taskId) async {
    return updateTaskStatus(
      taskId: taskId,
      status: 'UPCOMING',
    );
  }
  static Future<Map<String, dynamic>> getTaskSchema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      
      final headers = {
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
      };
      
      final response = await http.get(
        Uri.parse('$_physicalDeviceUrl/master/task/master/getAll'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('Error getting task schema: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> saveTaskWithDefaultRole({
    required int taskCategoryId,
    required String taskName,
    required String description,
    required String status,
    required String priority,
    String roleGroupName = 'Admin', 
  }) async {
    return saveTask(
      roleGroupName: roleGroupName,
      taskCategoryId: taskCategoryId,
      taskName: taskName,
      description: description,
      status: status,
      priority: priority,
    );
  }
  static Future<Map<String, dynamic>> fetchTasksByStatus(String status) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final validStatuses = ['UPCOMING', 'COMPLETED', 'TODAY'];
      if (!validStatuses.contains(status.toUpperCase())) {
        throw Exception('Invalid status. Must be one of: ${validStatuses.join(', ')}');
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (clinicId.isEmpty) throw Exception('Clinic ID missing');
      if (userId.isEmpty) throw Exception('User ID missing');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final url = '$_physicalDeviceUrl$_fetchTasksEndpoint/${status.toUpperCase()}';
      
      debugPrint('=== FETCH TASKS BY STATUS API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('Status: ${status.toUpperCase()}');
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      debugPrint('IMPORTANT: Response MUST contain task IDs in "id" or "taskId" field');

      final client = http.Client();
      
      try {
        final response = await client
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                client.close();
                throw Exception('Connection timeout. Server not responding at 192.168.1.14:8089');
              },
            );

        stopwatch.stop();
        debugPrint('=== FETCH TASKS BY STATUS API RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
        
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          
          Map<String, dynamic> formattedResponse;
          List<dynamic> tasksList = [];
          
          if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('data') && decoded['data'] is Map) {
              final data = decoded['data'] as Map;
              if (data.containsKey('list') && data['list'] is List) {
                tasksList = data['list'] as List;
              }
            }
            
            formattedResponse = {
              'data': tasksList,
              'message': decoded['message'] ?? 'Success',
              'status_code': 200,
              'status': status.toUpperCase(),
              'full_response': decoded,
            };
          } else {
            formattedResponse = {
              'data': [],
              'message': 'Unknown response format',
              'status_code': 200,
              'status': status.toUpperCase(),
            };
          }
          debugPrint('=== VALIDATING TASK IDs IN RESPONSE ===');
          int tasksWithIds = 0;
          int tasksWithoutIds = 0;
          for (var task in tasksList) {
            if (task is Map) {
              if (task.containsKey('id') || task.containsKey('taskId') || task.containsKey('task_id')) {
                tasksWithIds++;
              } else {
                tasksWithoutIds++;
                debugPrint('⚠️ Task without ID found: ${task['taskName'] ?? 'Unknown'}');
              }
            }
          }
          debugPrint('Tasks with IDs: $tasksWithIds, Tasks without IDs: $tasksWithoutIds');
          
          if (tasksWithoutIds > 0) {
            debugPrint('❌ WARNING: Some tasks do not have IDs. Update API will fail for these tasks!');
            debugPrint('❌ Backend must return task IDs in the fetch response.');
          }
          
          await _cacheTasksResponse(formattedResponse, status.toUpperCase());
          
          return formattedResponse;
        } else if (response.statusCode == 404) {
          return {
            'data': [],
            'message': 'No tasks found for status: ${status.toUpperCase()}',
            'status_code': 200,
            'status': status.toUpperCase()
          };
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please login again.');
        } else if (response.statusCode == 403) {
          throw Exception('Access forbidden. Check your permissions.');
        } else {
          throw Exception('Server returned status code: ${response.statusCode} for status: $status');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('MyTasksService Error (fetchTasksByStatus): $e');
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> fetchUpcomingTasks() async {
    return fetchTasksByStatus('UPCOMING');
  }
  static Future<Map<String, dynamic>> fetchCompletedTasks() async {
    return fetchTasksByStatus('COMPLETED');
  }
  static Future<Map<String, dynamic>> fetchTodayTasks() async {
    return fetchTasksByStatus('TODAY');
  }
  static Future<void> _cacheTasksResponse(Map<String, dynamic> response, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_tasks_${status.toLowerCase()}',
        jsonEncode({
          'response': response,
          'timestamp': DateTime.now().toIso8601String(),
          'status': status,
        }),
      );
      debugPrint('Tasks response for status $status cached successfully');
    } catch (e) {
      debugPrint('Error caching tasks response: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedTasksByStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_tasks_${status.toLowerCase()}');
      
      if (cachedJson != null) {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cached['timestamp'] as String);
        final now = DateTime.now();
        
        if (now.difference(timestamp).inMinutes < 5) {
          debugPrint('Returning cached tasks response for status: $status');
          return cached['response'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached tasks: $e');
      return null;
    }
  }
  static Future<void> clearTasksCache([String? status]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (status != null) {
        await prefs.remove('cached_tasks_${status.toLowerCase()}');
        debugPrint('Tasks cache cleared for status: $status');
      } else {
        final statuses = ['upcoming', 'completed', 'today'];
        for (final s in statuses) {
          await prefs.remove('cached_tasks_$s');
        }
        debugPrint('All tasks cache cleared');
      }
    } catch (e) {
      debugPrint('Error clearing tasks cache: $e');
    }
  }
  static Future<void> _cacheMasterCategoriesResponse(Map<String, dynamic> response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_master_categories',
        jsonEncode({
          'response': response,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      debugPrint('Master categories response cached successfully');
    } catch (e) {
      debugPrint('Error caching master categories response: $e');
    }
  }
  static Future<Map<String, dynamic>?> getCachedMasterCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_master_categories');
      
      if (cachedJson != null) {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cached['timestamp'] as String);
        final now = DateTime.now();
        
        if (now.difference(timestamp).inHours < 1) {
          debugPrint('Returning cached master categories response');
          return cached['response'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached master categories: $e');
      return null;
    }
  }

  static Future<bool> testConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      
      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) return false;
      
      final headers = {
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
      };
      
      final response = await http.get(
        Uri.parse('$_physicalDeviceUrl$_masterCategoryEndpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  static Future<void> clearMasterCategoriesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_master_categories');
      debugPrint('Master categories cache cleared');
    } catch (e) {
      debugPrint('Error clearing master categories cache: $e');
    }
  }

  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    if (sanitized['Authorization'] != null) {
      sanitized['Authorization'] = 'SmartCare ***';
    }
    if (sanitized['clinicid'] != null) {
      sanitized['clinicid'] = '***';
    }
    if (sanitized['userid'] != null) {
      sanitized['userid'] = '***';
    }
    return sanitized;
  }
}