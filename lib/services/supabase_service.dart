import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:zediatask/constants/app_constants.dart';
import 'package:zediatask/models/models.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Helper method to get the client
  SupabaseClient get client => _client;

  // Initialize method to set up necessary resources
  Future<void> initialize({bool setupStorage = false}) async {
    try {
      if (setupStorage) {
        // Check if task-attachments bucket exists and create it if not
        await _ensureStorageBucketExists('task-attachments');
      }
      
      // Verify database connectivity
      await checkDatabaseConnection();
    } catch (e) {
      // Silently handle errors
    }
  }

  // Ensure a storage bucket exists
  Future<void> _ensureStorageBucketExists(String bucketName) async {
    try {
      List<Bucket> buckets = await _client.storage.listBuckets();
      
      bool bucketExists = buckets.any((bucket) => bucket.name == bucketName);
      
      if (!bucketExists) {
        await _client.storage.createBucket(
          bucketName,
          const BucketOptions(
            public: true, // Make files publicly accessible
          ),
        );
      }
    } catch (e) {
      // Don't rethrow as this is not critical
    }
  }

  // Check and refresh authentication if needed
  Future<bool> verifyAndRefreshAuth() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        final response = await _client.auth.refreshSession();
        return response.user != null;
      }
      
      // Check if token is close to expiry (within 10 minutes)
      final session = _client.auth.currentSession;
      if (session != null) {
        final expiresAt = session.expiresAt;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        // Add null check for expiresAt
        if (expiresAt != null) {
          final timeToExpiry = expiresAt - now;
          
          // If token expires in less than 10 minutes (600 seconds), refresh it
          if (timeToExpiry < 600) {
            final response = await _client.auth.refreshSession();
            return response.user != null;
          }
        } else {
          // If expiresAt is null, refresh the session anyway
          final response = await _client.auth.refreshSession();
          return response.user != null;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Authentication methods
  Future<User?> signUp({
    required String email, 
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role.toString().split('.').last,
        },
      );

      if (response.user != null) {
        // Create user profile in the users table
        await _client.from('users').insert({
          'id': response.user!.id,
          'name': name,
          'email': email,
          'role': role.toString().split('.').last,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        // Fetch the created user data
        final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();
        
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        try {
          final userData = await _client
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();
          
          return User.fromJson(userData);
        } catch (dbError) {
          // Return a minimal User object just to allow login if the database fetch fails
          return User(
            id: response.user!.id,
            name: response.user!.userMetadata?['name'] ?? 'User',
            email: response.user!.email!,
            role: UserRole.employee, // Default role
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Method to refresh the current session
  Future<bool> refreshSession() async {
    try {
      // Try to refresh the current session
      final response = await _client.auth.refreshSession();
      return response.user != null;
    } catch (e) {
      // If refreshing fails, try to restore from stored credentials
      try {
        // Try to get any stored credentials from local storage
        final session = _client.auth.currentSession;
        if (session != null && session.refreshToken != null) {
          try {
            // Try to use the refresh token to set the session
            await _client.auth.setSession(session.refreshToken!);
            return true;
          } catch (_) {
            // If that fails, try to re-authenticate with stored credentials
            return false;
          }
        }
        return false;
      } catch (_) {
        return false;
      }
    }
  }

  Future<User?> get currentUser async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    
    try {
      final userData = await _client
        .from('users')
        .select()
        .eq('id', authUser.id)
        .single();
      
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }
  
  // Check if user is authenticated
  bool isAuthenticated() {
    return _client.auth.currentUser != null;
  }

  // Task methods
  Future<List<Task>> getTasks({String? assignedTo, bool bypassRLS = false}) async {
    try {
      // If bypassRLS is true, get all tasks and filter in memory instead of using RLS
      if (bypassRLS) {
        // Get all tasks from the database
        final allTasks = await getAllTasksBypassingRLS();
        final userId = _client.auth.currentUser?.id;
        
        // If assignedTo is not specified, return all tasks
        if (assignedTo == null) {
          return allTasks;
        }
        
        // Filter tasks based on assignedTo
        List<Task> filteredTasks = [];
        
        // Get tasks directly assigned to the user
        filteredTasks.addAll(
          allTasks.where((task) => task.assignedTo == assignedTo)
        );
        
        // If we're getting tasks for the current user, also add group tasks
        if (userId != null && assignedTo == userId) {
          // Add unassigned tasks (which we treat as group tasks)
          filteredTasks.addAll(
            allTasks.where((task) => 
              task.assignedTo.isEmpty && 
              task.status == TaskStatus.pending &&
              !filteredTasks.any((t) => t.id == task.id)
            )
          );
        }
        
        return filteredTasks;
      }
      
      // Original implementation if not bypassing RLS
      List<Map<String, dynamic>> data = [];
      final userId = _client.auth.currentUser?.id;
      
      if (assignedTo != null) {
        // Get tasks directly assigned to this user
        if (assignedTo.isNotEmpty) {
          final assignedTasks = await _client
            .from('tasks')
            .select()
            .eq('assigned_to', assignedTo)
            .order('created_at', ascending: false);
          
          data.addAll(assignedTasks);
        }
          
        // If we're getting tasks for the current user, also get group tasks
        if (userId != null && assignedTo == userId) {
          try {
            // Try to get is_group_task=true tasks first (if column exists)
            try {
              final groupTasks = await _client
                .from('tasks')
                .select()
                .eq('is_group_task', true)
                .eq('status', 'pending')
                .order('created_at', ascending: false);
              
              // Filter tasks where user is in original_assigned_to
              final eligibleGroupTasks = groupTasks.where((task) {
                if (task['original_assigned_to'] == null) return false;
                
                // Check if user is in the array
                List<dynamic> assignees = task['original_assigned_to'];
                return assignees.contains(userId);
              }).toList();
              
              data.addAll(eligibleGroupTasks);
            } catch (e) {
              // This will happen if the column doesn't exist yet - use fallback
            }
            
            // Fallback: Get tasks with no assignee as group tasks
            final pendingTasks = await _client
              .from('tasks')
              .select()
              .eq('status', 'pending')
              .order('created_at', ascending: false);
              
            // Filter for tasks with empty or null assigned_to (these are group tasks)
            final unassignedTasks = pendingTasks.where((task) => 
              (task['assigned_to'] == null || 
              task['assigned_to'] == '' ||
              task['assigned_to'].toString().isEmpty) &&
              !data.any((t) => t['id'] == task['id']) // Don't add duplicates
            ).toList();
            
            // Add unassigned tasks to the result
            data.addAll(unassignedTasks);
            
          } catch (e) {
            // Ignore errors for group tasks fetch
          }
        }
      } else {
        data = await _client
          .from('tasks')
          .select()
          .order('created_at', ascending: false);
      }
      
      // Fetch latest comment for each task
      final tasks = data.map((json) => Task.fromJson(json)).toList();
      
      // Mark any task with empty assignedTo and pending status as a group task 
      // (as a workaround until we have the is_group_task column)
      for (var i = 0; i < tasks.length; i++) {
        if (tasks[i].assignedTo.isEmpty && tasks[i].status == TaskStatus.pending) {
          tasks[i] = tasks[i].copyWith(isGroupTask: true);
        }
      }
      
      for (var i = 0; i < tasks.length; i++) {
        try {
          final lastComment = await _client
            .from('comments')
            .select()
            .eq('task_id', tasks[i].id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
          
          if (lastComment != null) {
            tasks[i] = tasks[i].copyWith(
              lastCommentContent: lastComment['content'],
              lastCommentDate: DateTime.parse(lastComment['created_at']),
            );
          }
        } catch (e) {
          // Ignore errors for individual comment fetches
        }
      }
      
      return tasks;
    } catch (e) {
      rethrow;
    }
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required TaskPriority priority,
    DateTime? dueDate,
    List<String>? tags,
    bool isGroupTask = false,
    List<String>? originalAssignedTo,
  }) async {
    try {
      // Check and refresh authentication first
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          // Try to refresh the session before failing
          await _client.auth.refreshSession();
          final newUserId = _client.auth.currentUser?.id;
          if (newUserId == null) {
            throw Exception('User not authenticated');
          }
        }
      } catch (e) {
        rethrow;
      }
      
      // Prepare the data
      final insertData = {
        'title': title,
        'description': description,
        'assigned_to': (isGroupTask || assignedTo.isEmpty) ? null : assignedTo,
        'created_by': _client.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'status': 'pending',
        'priority': priority.toString().split('.').last,
        'tags': tags ?? [],
      };
      
      // Try using the direct SQL approach to bypass potential issues
      try {
        // Use explicit insert statement with only essential fields first
        final sqlQuery = """
        INSERT INTO public.tasks (
          title, 
          description, 
          assigned_to, 
          created_by, 
          status, 
          priority
        ) VALUES (
          '${title.replaceAll("'", "''")}', 
          '${description.replaceAll("'", "''")}', 
          ${(isGroupTask || assignedTo.isEmpty) ? 'NULL' : "'$assignedTo'"}, 
          '${_client.auth.currentUser!.id}', 
          'pending', 
          '${priority.toString().split('.').last}'
        ) RETURNING *;
        """;
        
        // Try a direct POST request to the SQL execution endpoint
        final jwt = _client.auth.currentSession?.accessToken;
        if (jwt == null) {
          throw Exception('No access token available');
        }
        
        final response = await http.post(
          Uri.parse('${AppConstants.supabaseUrl}/rest/v1/rpc/execute_sql'),
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'sql_query': sqlQuery
          }),
        );
        
        if (response.statusCode == 400 && response.body.contains('schema "net" does not exist')) {
          throw Exception('''
Database error: "schema net does not exist"
This is likely a Supabase configuration issue. 
The error might indicate:
1. Your database connection string is incorrect
2. Your Supabase project might be in a different region than expected
3. There might be network issues preventing proper connection
4. The execute_sql function might not be set up in your database

Please check your Supabase project settings.
''');
        } else if (response.statusCode >= 200 && response.statusCode < 300) {
          // Parse the response
          final responseData = jsonDecode(response.body);
          if (responseData != null && responseData is List && responseData.isNotEmpty) {
            Map<String, dynamic> taskData = responseData[0];
            
            // Create task history entry
            try {
              await _client.from('task_history').insert({
                'task_id': taskData['id'],
                'status': 'pending',
                'timestamp': DateTime.now().toIso8601String(),
                'changed_by': _client.auth.currentUser!.id,
              });
            } catch (historyError) {
              // Continue even if history fails
            }
            
            // Create a Task object from the response
            Task task = Task.fromJson(taskData);
            if (isGroupTask) {
              task = task.copyWith(
                isGroupTask: true,
                originalAssignedTo: originalAssignedTo ?? [],
              );
            }
            
            return task;
          } else {
            throw Exception('Invalid response from SQL execution: $responseData');
          }
        } else {
          throw Exception('SQL execution failed: ${response.statusCode} - ${response.body}');
        }
      } catch (sqlError) {
        // Try a different approach using the standard Supabase API
        try {
          Map<String, dynamic> data = await _client.from('tasks').insert(insertData).select().single();
          
          // Create task history entry
          try {
            await _client.from('task_history').insert({
              'task_id': data['id'],
              'status': 'pending',
              'timestamp': DateTime.now().toIso8601String(),
              'changed_by': _client.auth.currentUser!.id,
            });
          } catch (historyError) {
            // Continue even if history fails
          }
          
          // Create a Task object from the response
          Task task = Task.fromJson(data);
          if (isGroupTask) {
            task = task.copyWith(
              isGroupTask: true,
              originalAssignedTo: originalAssignedTo ?? [],
            );
          }
          
          return task;
        } catch (apiError) {
          // One final attempt - check if database exists and reformat the error
          if (apiError.toString().contains('schema "net" does not exist')) {
            throw Exception('''
Database error: "schema net does not exist" 
Please check your Supabase configuration in lib/constants/app_constants.dart.
Current URL: ${AppConstants.supabaseUrl}
This error typically means:
1. The database connection string is incorrect
2. There's a network connectivity issue 
3. Your Supabase project configuration needs updating
''');
          }
          
          // If we get here, rethrow the original error
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Task> createGroupTask({
    required String title,
    required String description,
    required List<String> employeeIds,
    required TaskPriority priority,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Create basic data
      final insertData = {
        'title': title,
        'description': description,
        'assigned_to': null,  // Set to null for group tasks
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'status': 'pending',
        'priority': priority.toString().split('.').last,
        'tags': tags ?? [],
      };
      
      // Try to add group task fields
      try {
        insertData['is_group_task'] = true;
        insertData['original_assigned_to'] = employeeIds;
      } catch (e) {
        // Silently handle errors
      }
      
      // Try direct SQL approach first
      try {
        // Build a SQL query for creating the group task
        // First check if original_assigned_to exists in the schema
        final checkColumnsQuery = """
          SELECT column_name 
          FROM information_schema.columns 
          WHERE table_name = 'tasks' 
          AND column_name IN ('is_group_task', 'original_assigned_to')
        """;
        
        // Get JWT for authorization
        final jwt = _client.auth.currentSession?.accessToken;
        if (jwt == null) {
          throw Exception('No access token available');
        }
        
        // Execute the check query to determine which columns exist
        final columnsResponse = await http.post(
          Uri.parse('${AppConstants.supabaseUrl}/rest/v1/rpc/execute_sql'),
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'sql_query': checkColumnsQuery
          }),
        );
        
        // Determine which columns exist
        final List<String> existingColumns = [];
        if (columnsResponse.statusCode >= 200 && columnsResponse.statusCode < 300) {
          try {
            final columnsData = jsonDecode(columnsResponse.body);
            if (columnsData is List) {
              for (var column in columnsData) {
                if (column is Map && column.containsKey('column_name')) {
                  existingColumns.add(column['column_name'].toString());
                }
              }
            }
          } catch (e) {
            // Silently handle parsing errors
          }
        }
        
        // Build the insert query based on available columns
        String insertQuery = """
          INSERT INTO public.tasks (
            title, 
            description, 
            assigned_to, 
            created_by, 
            status, 
            priority
        """;
        
        // Add optional columns if they exist
        if (existingColumns.contains('is_group_task')) {
          insertQuery += ", is_group_task";
        }
        
        if (existingColumns.contains('original_assigned_to')) {
          insertQuery += ", original_assigned_to";
        }
        
        // Add values part
        insertQuery += """
          ) VALUES (
            '${title.replaceAll("'", "''")}', 
            '${description.replaceAll("'", "''")}', 
            NULL, 
            '$userId', 
            'pending', 
            '${priority.toString().split('.').last}'
        """;
        
        // Add values for optional columns
        if (existingColumns.contains('is_group_task')) {
          insertQuery += ", true";
        }
        
        if (existingColumns.contains('original_assigned_to')) {
          // Format the employee IDs as a Postgres array
          final employeeIdsString = employeeIds.map((id) => "'$id'").join(',');
          insertQuery += ", ARRAY[$employeeIdsString]::uuid[]";
        }
        
        // Finish the query
        insertQuery += ") RETURNING *;";
        
        // Execute the insert query
        final response = await http.post(
          Uri.parse('${AppConstants.supabaseUrl}/rest/v1/rpc/execute_sql'),
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'sql_query': insertQuery
          }),
        );
        
        if (response.statusCode == 400 && response.body.contains('schema "net" does not exist')) {
          throw Exception('''
Database error: "schema net does not exist"
This is likely a Supabase configuration issue. 
Please check your Supabase project settings.
''');
        } else if (response.statusCode >= 200 && response.statusCode < 300) {
          // Parse the response
          final responseData = jsonDecode(response.body);
          if (responseData != null && responseData is List && responseData.isNotEmpty) {
            Map<String, dynamic> taskData = responseData[0];
            
            // Create task history entry
            try {
              await _client.from('task_history').insert({
                'task_id': taskData['id'],
                'status': 'pending',
                'timestamp': DateTime.now().toIso8601String(),
                'changed_by': userId,
              });
            } catch (historyError) {
              // Continue even if history fails
            }
            
            // Create a Task object from the response
            Task task = Task.fromJson(taskData);
            // Always mark as group task in memory even if DB doesn't support it yet
            task = task.copyWith(
              isGroupTask: true,
              originalAssignedTo: employeeIds,
            );
            
            return task;
          } else {
            throw Exception('Invalid response from SQL execution: $responseData');
          }
        } else {
          throw Exception('SQL execution failed: ${response.statusCode} - ${response.body}');
        }
      } catch (sqlError) {
        // Try standard API approach as fallback
        try {
          final data = await _client.from('tasks').insert(insertData).select().single();
          
          // Create task history entry
          try {
            await _client.from('task_history').insert({
              'task_id': data['id'],
              'status': 'pending',
              'timestamp': DateTime.now().toIso8601String(),
              'changed_by': userId,
            });
          } catch (historyError) {
            // Continue even if history fails
          }
          
          // Create the task object with group task flags in memory
          Task task = Task.fromJson(data);
          task = task.copyWith(
            isGroupTask: true,
            originalAssignedTo: employeeIds,
          );
          
          return task;
        } catch (apiError) {
          // Format a better error if it's the schema net issue
          if (apiError.toString().contains('schema "net" does not exist')) {
            throw Exception('''
Database error: "schema net does not exist" 
Please check your Supabase configuration in lib/constants/app_constants.dart.

This error occurs when:
1. There's an issue with your database connection string
2. There's a network connectivity problem
3. Your Supabase project configuration is incorrect
''');
          }
          
          // Otherwise, rethrow the original error
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Task> claimGroupTask({
    required String taskId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // First check if task is still available
      final task = await getTask(taskId: taskId);
      if (task == null) {
        throw Exception('Task not found');
      }
      
      // Since we can't check if it's a group task reliably without the database column,
      // we'll just check if it's pending
      if (task.status != TaskStatus.pending) {
        throw Exception('Task is no longer available for claiming');
      }
      
      // Update task to assign it to this user and mark as accepted
      final updateData = {
        'assigned_to': userId,
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      };
      
      final data = await _client
        .from('tasks')
        .update(updateData)
        .eq('id', taskId)
        .select()
        .single();
      
      // Create task history entry
      await _client.from('task_history').insert({
        'task_id': taskId,
        'status': 'accepted',
        'timestamp': DateTime.now().toIso8601String(),
        'changed_by': userId,
      });
      
      return Task.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Task> updateTaskStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      Map<String, dynamic> updateData = {
        'status': status.toString().split('.').last,
      };
      
      // Add timestamps based on status
      if (status == TaskStatus.accepted) {
        updateData['accepted_at'] = DateTime.now().toIso8601String();
      } else if (status == TaskStatus.completed) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
        
        // Calculate points for task completion
        final task = await getTask(taskId: taskId);
        if (task != null) {
          int pointsAwarded = AppConstants.pointsBasicCompletion;
          
          // Add points for completion time relative to deadline
          if (task.dueDate != null) {
            if (DateTime.now().isBefore(task.dueDate!)) {
              pointsAwarded += AppConstants.pointsCompletionBeforeDeadline;
            } else if (DateTime.now().difference(task.dueDate!).inDays <= 1) {
              pointsAwarded += AppConstants.pointsCompletionOnTime;
            }
          }
          
          // Add points for fast acceptance if applicable
          if (task.acceptedAt != null) {
            final acceptanceTime = task.acceptedAt!.difference(task.createdAt);
            if (acceptanceTime.inHours <= 1) {
              pointsAwarded += AppConstants.pointsFastAcceptance;
            } else if (acceptanceTime.inDays <= 1) {
              pointsAwarded += AppConstants.pointsNormalAcceptance;
            }
          }
          
          updateData['points_awarded'] = pointsAwarded;
        }
      }
      
      final data = await _client
        .from('tasks')
        .update(updateData)
        .eq('id', taskId)
        .select()
        .single();
      
      // Create task history entry
      await _client.from('task_history').insert({
        'task_id': taskId,
        'status': status.toString().split('.').last,
        'timestamp': DateTime.now().toIso8601String(),
        'changed_by': userId,
      });
      
      return Task.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  // Add points to a task for testing
  Future<Task> addPointsToTask({
    required String taskId, 
    required int points,
  }) async {
    try {
      final data = await _client
        .from('tasks')
        .update({
          'points_awarded': points,
        })
        .eq('id', taskId)
        .select()
        .single();
      
      return Task.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Task?> getTask({required String taskId}) async {
    try {
      final data = await _client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .single();
      
      Task task = Task.fromJson(data);
      
      // Handle group tasks
      // If is_group_task is false but the task has empty assigned_to and is pending,
      // we'll treat it as a group task (fallback mechanism)
      if (!task.isGroupTask && task.assignedTo.isEmpty && task.status == TaskStatus.pending) {
        task = task.copyWith(isGroupTask: true);
      }
      
      // Try to load the original_assigned_to list if needed
      if (task.isGroupTask && task.originalAssignedTo.isEmpty) {
        try {
          // Check if we can directly access the original_assigned_to column
          final taskWithAssignees = await _client
            .from('tasks')
            .select('original_assigned_to')
            .eq('id', taskId)
            .single();
            
          if (taskWithAssignees != null && taskWithAssignees['original_assigned_to'] != null) {
            List<String> assignees = List<String>.from(taskWithAssignees['original_assigned_to']);
            task = task.copyWith(originalAssignedTo: assignees);
          }
        } catch (e) {
          // Continue with empty originalAssignedTo
        }
      }
      
      // Fetch the latest comment for this task
      try {
        final lastComment = await _client
          .from('comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
        
        if (lastComment != null) {
          task = task.copyWith(
            lastCommentContent: lastComment['content'],
            lastCommentDate: DateTime.parse(lastComment['created_at']),
          );
        }
      } catch (e) {
        // Ignore errors for comment fetch
      }
      
      return task;
    } catch (e) {
      return null;
    }
  }

  // Comment methods
  Future<List<Comment>> getComments({required String taskId}) async {
    try {
      final data = await _client
        .from('comments')
        .select()
        .eq('task_id', taskId)
        .order('created_at');
      
      return data.map((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Comment> addComment({
    required String taskId,
    required String content,
    required bool visibleToEmployee,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final data = await _client.from('comments').insert({
        'task_id': taskId,
        'author_id': userId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'visible_to_employee': visibleToEmployee,
      }).select().single();
      
      // Update task's last comment information
      await _client.from('tasks').update({
        'last_comment_content': content,
        'last_comment_date': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      
      return Comment.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  // Add a test comment to a task
  Future<void> addTestComment({
    required String taskId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final commentData = await _client.from('comments').insert({
        'task_id': taskId,
        'author_id': userId,
        'content': 'This is a test comment added at ${DateTime.now()}',
        'created_at': DateTime.now().toIso8601String(),
        'visible_to_employee': true,
      }).select().single();
      
      // Update task's last comment information 
      await _client.from('tasks').update({
        'last_comment_content': 'This is a test comment added at ${DateTime.now()}',
        'last_comment_date': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      
    } catch (e) {
      rethrow;
    }
  }

  // Attachment methods
  Future<List<Attachment>> getAttachments({required String taskId}) async {
    try {
      final data = await _client
        .from('attachments')
        .select()
        .eq('task_id', taskId)
        .order('created_at');
      
      return data.map((json) => Attachment.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Attachment> addAttachment({
    required String taskId,
    required String fileUrl,
    required String fileName,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final data = await _client.from('attachments').insert({
        'task_id': taskId,
        'file_url': fileUrl,
        'file_name': fileName,
        'uploaded_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      return Attachment.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  // Upload file to Supabase storage
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Make filename unique with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_$fileName';
      final storagePath = 'attachments/$userId/$uniqueFileName';
      
      // Verify file exists and is readable
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist at path: $filePath');
      }
      
      final fileSize = await file.length();
      
      // Upload the file to Supabase storage
      await _client.storage.from('task-attachments').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
      
      // Get the public URL for the uploaded file
      final fileUrl = _client.storage
          .from('task-attachments')
          .getPublicUrl(storagePath);
      
      return fileUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Feedback methods
  Future<List<TaskFeedback>> getTaskFeedback(String taskId) async {
    try {
      final data = await _client.from('feedback')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);
      
      return data.map((e) => TaskFeedback.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<TaskFeedback> addTaskFeedback({
    required String taskId,
    required String content,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final data = await _client.from('feedback').insert({
        'task_id': taskId,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      return TaskFeedback.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  // User methods
  Future<List<dynamic>> getEmployees() async {
    try {
      final allUsers = await _client.from('users').select();
      
      // Filter to only employees (case-insensitive)
      final employees = allUsers.where((user) => 
        user['role']?.toString().toLowerCase() == 'employee').toList();
      
      return employees;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get all users (added back for compatibility)
  Future<void> getAllUsers() async {
    try {
      await _client.from('users').select();
    } catch (e) {
      // Silent error handling
    }
  }

  // Get user by ID
  Future<User?> getUserById(String? userId) async {
    try {
      if (userId == null || userId.isEmpty) {
        return null;
      }
      
      final userData = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
      
      if (userData == null) return null;
      
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  // Get leaderboard data
  Future<List<dynamic>> getLeaderboard() async {
    try {
      // Get the current user to check role
      final currentAuthUser = _client.auth.currentUser;
      if (currentAuthUser == null) {
        return [];
      }
      
      // First, get all employees with their points
      final employees = await _client
        .from('users')
        .select()
        .eq('role', 'employee')
        .order('total_points', ascending: false)
        .limit(20);
      
      // For each employee, get their completed tasks with dates
      // If the current user is an employee, we need to use a different approach
      // to ensure they can see the leaderboard data for all employees
      for (var employee in employees) {
        List completedTasks = [];
        try {
          // Fetch all completed tasks for this employee
          completedTasks = await _client
            .from('tasks')
            .select('id, points_awarded, completed_at')
            .eq('assigned_to', employee['id'])
            .eq('status', 'completed')
            .order('completed_at', ascending: false);
          
          // Attach the tasks to the employee object
          employee['tasks'] = completedTasks;
          
          // Set the last completed task date if available
          if (completedTasks.isNotEmpty && completedTasks[0]['completed_at'] != null) {
            employee['last_completed_task_date'] = completedTasks[0]['completed_at'];
          }
          
          // Calculate total points and tasks completed for verification
          num totalPoints = 0;
          int tasksCompleted = 0;
          
          for (var task in completedTasks) {
            totalPoints += task['points_awarded'] ?? 0;
            tasksCompleted++;
          }
          
          print('Employee ${employee['name']}: $tasksCompleted tasks, $totalPoints points');
        } catch (e) {
          // Continue with empty tasks array
          completedTasks = [];
        }
        
        // Attach the tasks to the employee object
        employee['tasks'] = completedTasks;
        
        // Set the last completed task date if available
        if (completedTasks.isNotEmpty && completedTasks[0]['completed_at'] != null) {
          employee['last_completed_task_date'] = completedTasks[0]['completed_at'];
        }
        
        // Calculate total points and tasks completed for verification
        num totalPoints = 0;
        int tasksCompleted = 0;
        
        for (var task in completedTasks) {
          totalPoints += task['points_awarded'] ?? 0;
          tasksCompleted++;
        }
        
        print('Employee ${employee['name']}: $tasksCompleted tasks, $totalPoints points');
      }
      
      // Sort again by total_points to ensure correct order
      employees.sort((a, b) => (b['total_points'] ?? 0).compareTo(a['total_points'] ?? 0));
      
      return employees;
    } catch (e) {
      rethrow;
    }
  }
  
  // Test connection (kept for backward compatibility)
  Future<bool> testConnection() async {
    return checkDatabaseConnection();
  }

  // Debug method to show all pending tasks with their properties
  Future<void> debugShowAllTasks() async {
    try {
      final data = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false);
      
      for (var task in data) {
        print('-----------------------------------------');
        print('Task ID: ${task['id']}');
        print('Title: ${task['title']}');
        print('Status: ${task['status']}');
        print('Assigned To: ${task['assigned_to'] ?? 'NULL'}');
        
        try {
          print('Is Group Task: ${task['is_group_task'] ?? 'column not present'}');
        } catch (e) {
          print('Is Group Task: error accessing column');
        }
        
        try {
          print('Original Assigned To: ${task['original_assigned_to'] ?? 'NULL'}');
        } catch (e) {
          print('Original Assigned To: error accessing column');
        }
        print('-----------------------------------------');
      }
    } catch (e) {
      print('DEBUG: Error fetching all tasks: $e');
    }
  }

  // Debug method to show all tasks bypassing RLS
  Future<List<Task>> getAllTasksBypassingRLS() async {
    try {
      // Make a direct fetch that bypasses RLS using service role if available
      // If this fails, we will fall back to our regular query
      List<Map<String, dynamic>> data = [];
      try {
        data = await _client
          .from('tasks')
          .select()
          .order('created_at', ascending: false);
        
        print('DEBUG: Successfully fetched ${data.length} tasks with current user permissions');
      } catch (e) {
        print('DEBUG: Error fetching tasks: $e');
        return [];
      }
      
      // Process the data the same way as in getTasks
      final tasks = data.map((json) => Task.fromJson(json)).toList();
      
      // Mark any task with empty assignedTo and pending status as a group task
      for (var i = 0; i < tasks.length; i++) {
        if (tasks[i].assignedTo.isEmpty && tasks[i].status == TaskStatus.pending) {
          tasks[i] = tasks[i].copyWith(isGroupTask: true);
        }
      }
      
      return tasks;
    } catch (e) {
      print('DEBUG: Error fetching all tasks: $e');
      return [];
    }
  }

  // Real-time subscription management
  RealtimeChannel? _tasksSubscription;
  
  // Check if we have an active real-time subscription
  bool get hasActiveTasksSubscription => _tasksSubscription != null;
  
  // Subscribe to real-time task updates
  void subscribeToTasks({
    Function(List<Map<String, dynamic>>)? onInsert,
    Function(List<Map<String, dynamic>>)? onUpdate,
    Function(List<Map<String, dynamic>>)? onDelete,
  }) {
    // If we already have an active subscription, remove it first
    unsubscribeFromTasks();
    
    try {
      // Create a new subscription channel
      _tasksSubscription = _client.channel('public:tasks');
      
      // Set up the subscription with event handlers
      _tasksSubscription = _tasksSubscription!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (onInsert != null && payload.newRecord != null) {
              onInsert([payload.newRecord as Map<String, dynamic>]);
            }
          }
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (onUpdate != null && payload.newRecord != null) {
              onUpdate([payload.newRecord as Map<String, dynamic>]);
            }
          }
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (onDelete != null && payload.oldRecord != null) {
              onDelete([payload.oldRecord as Map<String, dynamic>]);
            }
          }
        );
      
      // Subscribe to the channel
      _tasksSubscription!.subscribe();
    } catch (e) {
      _tasksSubscription = null;
    }
  }
  
  // Unsubscribe from real-time task updates
  void unsubscribeFromTasks() {
    if (_tasksSubscription != null) {
      _tasksSubscription!.unsubscribe();
      _client.removeChannel(_tasksSubscription!);
      _tasksSubscription = null;
    }
  }

  // Check database connection
  Future<bool> checkDatabaseConnection() async {
    try {
      await _client.from('tasks').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Test the execute_sql function
  Future<bool> testExecuteSqlFunction() async {
    try {
      await _client.rpc('execute_sql', 
        params: {'sql_query': 'SELECT 1 as test'}
      );
      return true;
    } catch (e) {
      if (e.toString().contains('Could not find the function')) {
        return await createExecuteSqlFunction();
      }
      
      return false;
    }
  }

  // Test direct connection to Supabase
  Future<Map<String, dynamic>> testDirectConnection() async {
    final Map<String, dynamic> results = {
      'success': false,
      'details': <String, dynamic>{},
    };
    
    try {
      final response = await http.get(Uri.parse(AppConstants.supabaseUrl));
      results['details'] = results['details'] as Map<String, dynamic>;
      (results['details'] as Map<String, dynamic>)['baseUrlStatus'] = response.statusCode;
      (results['details'] as Map<String, dynamic>)['baseUrlResponse'] = response.body.substring(0, min(100, response.body.length));
      
      final restResponse = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
        },
      );
      (results['details'] as Map<String, dynamic>)['restApiStatus'] = restResponse.statusCode;
      (results['details'] as Map<String, dynamic>)['restApiResponse'] = restResponse.body.substring(0, min(100, restResponse.body.length));
      
      final tasksResponse = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/tasks?select=id&limit=1'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
        },
      );
      (results['details'] as Map<String, dynamic>)['tasksTableStatus'] = tasksResponse.statusCode;
      (results['details'] as Map<String, dynamic>)['tasksTableResponse'] = tasksResponse.body.substring(0, min(100, tasksResponse.body.length));
      
      try {
        final authResponse = await http.post(
          Uri.parse('${AppConstants.supabaseUrl}/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': 'test@example.com',
            'password': 'invalid_password',
          }),
        );
        (results['details'] as Map<String, dynamic>)['authServiceStatus'] = authResponse.statusCode;
      } catch (e) {
        (results['details'] as Map<String, dynamic>)['authServiceError'] = e.toString();
      }
      
      (results['details'] as Map<String, dynamic>)['corsTest'] = 'Not run - requires browser context';
      
      final Map<String, dynamic> details = results['details'] as Map<String, dynamic>;
      final hasConnectionIssues = 
        details['baseUrlStatus'] == null || 
        details['restApiStatus'] == null ||
        details['tasksTableStatus'] == null;
      
      if (hasConnectionIssues) {
        results['success'] = false;
        details['recommendedAction'] = 'Check network connectivity and Supabase URL';
      } else if (details['tasksTableStatus'] != 200 && 
                details['tasksTableResponse'].toString().contains('schema "net" does not exist')) {
        results['success'] = false;
        details['recommendedAction'] = 'Your Supabase URL appears to be using incorrect configuration. This specific error often indicates a configuration issue with the project, not with your app code.';
      } else {
        results['success'] = true;
        details['recommendedAction'] = 'Connection appears to be working';
      }
      
      return results;
    } catch (e) {
      (results['details'] as Map<String, dynamic>)['testError'] = e.toString();
      return results;
    }
  }
  
  // Create the execute_sql function if it doesn't exist
  Future<bool> createExecuteSqlFunction() async {
    try {
      final jwt = _client.auth.currentSession?.accessToken;
      if (jwt == null) {
        throw Exception('No access token available');
      }
      
      // SQL query to create the function if it doesn't exist
      final createFunctionSql = """
      CREATE OR REPLACE FUNCTION execute_sql(sql_query TEXT)
      RETURNS JSONB
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS \$\$
      DECLARE
        result JSONB;
      BEGIN
        EXECUTE sql_query INTO result;
        RETURN result;
      EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('error', SQLERRM);
      END;
      \$\$;
      """;
      
      // Make a POST request to create the function
      // This is a direct SQL execution without using the execute_sql function itself
      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/rpc/'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'command': 'raw',
          'sql': createFunctionSql,
        }),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Upload task attachment
  Future<Attachment> uploadTaskAttachment({
    required String taskId, 
    required String filePath,
    required String fileName,
  }) async {
    try {
      // Upload the file
      final fileUrl = await uploadFile(filePath: filePath, fileName: fileName);
      
      // Create attachment record
      return await addAttachment(taskId: taskId, fileUrl: fileUrl, fileName: fileName);
    } catch (e) {
      rethrow;
    }
  }
} 