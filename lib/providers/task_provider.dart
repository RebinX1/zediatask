import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/providers/notification_provider.dart';
import 'package:zediatask/services/services.dart';
import 'dart:async';

// Global stream controller for task notifications
// This is needed because StateNotifier can't directly access WidgetRef
final taskNotificationSubject = StreamController<Map<String, dynamic>>.broadcast();

// Stream provider for task notifications
final taskNotificationStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return taskNotificationSubject.stream;
});

// Date Filter enum
enum DateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  custom,
}

// Date range provider for custom date filter
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Date filter provider
final dateFilterProvider = StateProvider<DateFilter>((ref) => DateFilter.all);

// All tasks provider - accessible by managers and admins
final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getTasks(bypassRLS: true);
});

// User-specific tasks based on role
final userTasksProvider = FutureProvider<List<Task>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  
  // Get logged in user from our state provider first for better reliability
  final loggedInUser = ref.watch(loggedInUserProvider);
  final User? user = loggedInUser ?? await supabaseService.currentUser;
  
  if (user == null) return [];

  // Always bypass RLS for all users to handle group tasks correctly
  print('Bypassing RLS to get tasks for user ${user.id} (${user.role})');
  
  // If user is manager or admin, show all tasks
  if (user.isManager) {
    print('User is manager/admin, showing all tasks');
    return await supabaseService.getTasks(bypassRLS: true);
  }
  
  // Otherwise, show only tasks assigned to this user + group tasks (bypassing RLS)
  print('User is employee, showing assigned tasks + group tasks');
  return await supabaseService.getTasks(assignedTo: user.id, bypassRLS: true);
});

// Selected task provider
final selectedTaskIdProvider = StateProvider<String?>((ref) => null);

final selectedTaskProvider = FutureProvider<Task?>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final taskId = ref.watch(selectedTaskIdProvider);
  
  if (taskId == null) return null;
  
  // Using the bypass RLS approach with direct fetch
  try {
    final allTasks = await supabaseService.getAllTasksBypassingRLS();
    final task = allTasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    return task;
  } catch (e) {
    print('Error getting task via bypass: $e, falling back to normal getTask');
    return await supabaseService.getTask(taskId: taskId);
  }
});

// Task comments provider (non-realtime)
final taskCommentsProvider = FutureProvider.family<List<Comment>, String>((ref, taskId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getComments(taskId: taskId);
});

// Real-time comments provider using streams
final realtimeCommentsProvider = StateNotifierProvider.family<RealtimeCommentsNotifier, List<Comment>, String>((ref, taskId) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RealtimeCommentsNotifier(supabaseService, taskId);
});

// Task attachments provider
final taskAttachmentsProvider = FutureProvider.family<List<Attachment>, String>((ref, taskId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getAttachments(taskId: taskId);
});

// Task filtered by status and date
final filteredTasksProvider = FutureProvider.family<List<Task>, TaskStatus?>((ref, status) async {
  final userTasksFuture = ref.watch(userTasksProvider.future);
  final tasks = await userTasksFuture;
  final dateFilter = ref.watch(dateFilterProvider);
  final dateRange = ref.watch(dateRangeProvider);
  
  // Filter by date
  List<Task> dateFilteredTasks = _filterTasksByDate(tasks, dateFilter, dateRange);
  
  // Then filter by status
  if (status == null) return dateFilteredTasks;
  
  return dateFilteredTasks.where((task) => task.status == status).toList();
});

// Admin-specific filtered tasks provider that doesn't depend on task updates
final adminFilteredTasksProvider = FutureProvider.family<List<Task>, TaskStatus?>((ref, status) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  final tasks = await supabaseService.getTasks();
  final dateFilter = ref.watch(dateFilterProvider);
  final dateRange = ref.watch(dateRangeProvider);
  
  // Filter by date
  List<Task> dateFilteredTasks = _filterTasksByDate(tasks, dateFilter, dateRange);
  
  // Then filter by status
  if (status == null) return dateFilteredTasks;
  
  return dateFilteredTasks.where((task) => task.status == status).toList();
});

// Real-time filtered tasks provider
final realtimeFilteredTasksProvider = Provider.family<List<Task>, TaskStatus?>((ref, status) {
  final allTasks = ref.watch(realtimeTasksProvider);
  final dateFilter = ref.watch(dateFilterProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final currentUser = ref.watch(loggedInUserProvider);
  
  // First filter for user-specific tasks
  List<Task> userTasks;
  
  if (currentUser == null) {
    userTasks = [];
  } else if (currentUser.isManager) {
    // Managers see all tasks
    userTasks = allTasks;
  } else {
    // Employees see assigned + group tasks
    userTasks = allTasks.where((task) {
      // Include tasks assigned directly to this user
      if (task.assignedTo == currentUser.id) return true;
      
      // Include group tasks (unassigned + pending)
      if (task.assignedTo.isEmpty && task.status == TaskStatus.pending) return true;
      
      return false;
    }).toList();
  }
  
  // Filter by date
  List<Task> dateFilteredTasks = _filterTasksByDate(userTasks, dateFilter, dateRange);
  
  // Then filter by status
  if (status == null) return dateFilteredTasks;
  
  return dateFilteredTasks.where((task) => task.status == status).toList();
});

// Task update notifier to signal when tasks are updated (completed, accepted, etc.)
// Using DateTime to ensure each update has a unique value
final taskUpdateNotifierProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Stream controller to broadcast real-time task updates
final _taskStreamController = StreamController<void>.broadcast();

// Task stream provider to trigger UI refreshes when real-time data arrives
final taskStreamProvider = StreamProvider<void>((ref) {
  return _taskStreamController.stream;
});

// Utility function to notify that a task has been updated
void notifyTaskUpdate(WidgetRef ref) {
  // Set the current timestamp to trigger a state change
  print('Task update notification sent: ${DateTime.now()}');
  ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
  
  // Broadcast to the stream to trigger UI updates
  _taskStreamController.add(null);
}

// Real-time tasks notifier to handle Supabase real-time events
class RealtimeTasksNotifier extends StateNotifier<List<Task>> {
  final SupabaseService _supabaseService;
  bool _disposed = false;
  
  RealtimeTasksNotifier(this._supabaseService) : super([]) {
    // Initial load of tasks
    _loadInitialTasks();
    
    // Set up real-time subscription
    _setupRealtimeSubscription();
  }
  
  Future<void> _loadInitialTasks() async {
    if (_disposed) return;
    try {
      final tasks = await _supabaseService.getAllTasksBypassingRLS();
      if (_disposed) return;
      
      // Sort tasks with newest first for consistency
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      state = tasks;
      print('Loaded ${tasks.length} initial tasks for real-time provider');
    } catch (e) {
      print('Error loading initial tasks for real-time provider: $e');
    }
  }
  
  void _setupRealtimeSubscription() {
    if (_disposed) return;
    
    _supabaseService.subscribeToTasks(
      onInsert: (records) {
        if (_disposed) return;
        _handleInsert(records);
      },
      onUpdate: (records) {
        if (_disposed) return;
        _handleUpdate(records);
      },
      onDelete: (records) {
        if (_disposed) return;
        _handleDelete(records);
      },
    );
  }
  
  void _handleInsert(List<Map<String, dynamic>> records) {
    if (_disposed) return;
    
    final newTasks = records.map((record) => Task.fromJson(record)).toList();
    
    // Mark any task with empty assignedTo and pending status as a group task
    for (var i = 0; i < newTasks.length; i++) {
      if (newTasks[i].assignedTo.isEmpty && newTasks[i].status == TaskStatus.pending) {
        newTasks[i] = newTasks[i].copyWith(isGroupTask: true);
      }
    }
    
    // Create a new state list to ensure UI updates
    final updatedState = [...newTasks, ...state]; // Add new tasks at the TOP of the list
    if (_disposed) return;
    
    // Force multiple state updates to ensure UI refreshes
    state = [];
    Future.microtask(() {
      if (_disposed) return;
      state = updatedState;
    });
    
    // Show notifications for new tasks
    _showTaskNotifications(newTasks);
    
    print('Added ${newTasks.length} new tasks via real-time. Total tasks: ${updatedState.length}');
    
    // We need to let the global taskUpdateNotifierProvider know about this change,
    // but we can't access it directly from here. The UI components watching realtime
    // tasks will handle this through their periodic refresh.
  }
  
  // Helper method to show notifications for new tasks
  void _showTaskNotifications(List<Task> newTasks) {
    try {
      // Since we can't access the WidgetRef directly from the StateNotifier,
      // we use a global function to post a notification event
      for (final task in newTasks) {
        // Create a notification with task details
        final notificationTitle = 'New Task: ${task.title}';
        final notificationBody = task.description.length > 100 
            ? '${task.description.substring(0, 97)}...' 
            : task.description;
            
        // Post this task notification (will be picked up by the main app)
        taskNotificationSubject.add({
          'title': notificationTitle,
          'body': notificationBody,
          'task': task,
        });
        
        print('Posted task notification: $notificationTitle');
      }
    } catch (e) {
      print('Error showing task notification: $e');
    }
  }
  
  void _handleUpdate(List<Map<String, dynamic>> records) {
    if (_disposed) return;
    
    // Create a new list to ensure state change is detected
    final List<Task> updatedState = [...state];
    
    for (final record in records) {
      var updatedTask = Task.fromJson(record);
      
      // Mark as group task if appropriate
      if (updatedTask.assignedTo.isEmpty && updatedTask.status == TaskStatus.pending) {
        updatedTask = updatedTask.copyWith(isGroupTask: true);
      }
      
      // Find and replace the updated task
      final index = updatedState.indexWhere((task) => task.id == updatedTask.id);
      if (index >= 0) {
        updatedState[index] = updatedTask;
      } else {
        // If not found, add it
        updatedState.add(updatedTask);
      }
    }
    
    if (_disposed) return;
    
    // Force multiple state updates to ensure UI refreshes
    state = [];
    Future.microtask(() {
      if (_disposed) return;
      state = updatedState;
    });
    
    print('Updated tasks via real-time. Total tasks: ${updatedState.length}');
    
    // UI components will handle refresh through periodic timer
  }
  
  void _handleDelete(List<Map<String, dynamic>> records) {
    if (_disposed) return;
    
    final taskIds = records.map((record) => record['id'].toString()).toSet();
    final updatedState = state.where((task) => !taskIds.contains(task.id)).toList();
    if (_disposed) return;
    
    // Force multiple state updates to ensure UI refreshes
    state = [];
    Future.microtask(() {
      if (_disposed) return;
      state = updatedState;
    });
    
    print('Removed tasks via real-time. Remaining tasks: ${updatedState.length}');
    
    // UI components will handle refresh through periodic timer
  }
  
  @override
  void dispose() {
    _disposed = true;
    _supabaseService.unsubscribeFromTasks();
    super.dispose();
  }
  
  // Public method to manually refresh tasks
  Future<void> refreshTasks() async {
    if (_disposed) return;
    await _loadInitialTasks();
    
    // Force UI refresh
    Future.microtask(() {
      if (_disposed) return;
      
      // Create a new list to force state change detection
      final refreshedState = [...state];
      state = refreshedState;
      
      // UI components will handle refresh through periodic timer
    });
  }
}

// Provider for real-time tasks
final realtimeTasksProvider = StateNotifierProvider<RealtimeTasksNotifier, List<Task>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RealtimeTasksNotifier(supabaseService);
});

// Helper function to filter tasks by date
List<Task> _filterTasksByDate(List<Task> tasks, DateFilter dateFilter, DateTimeRange? customDateRange) {
  if (dateFilter == DateFilter.all) {
    return tasks;
  }
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  switch (dateFilter) {
    case DateFilter.today:
      return tasks.where((task) {
        final taskDate = task.createdAt.toLocal();
        return taskDate.year == today.year && 
               taskDate.month == today.month && 
               taskDate.day == today.day;
      }).toList();
      
    case DateFilter.thisWeek:
      // Start of week (Monday)
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      // End of week (Sunday)
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      return tasks.where((task) {
        final taskDate = task.createdAt.toLocal();
        return taskDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
               taskDate.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      }).toList();
      
    case DateFilter.thisMonth:
      // First day of current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      // Last day of current month
      final endOfMonth = (now.month < 12) 
          ? DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1))
          : DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1));
      
      return tasks.where((task) {
        final taskDate = task.createdAt.toLocal();
        return taskDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
               taskDate.isBefore(endOfMonth.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
      }).toList();
      
    case DateFilter.custom:
      if (customDateRange != null) {
        final start = customDateRange.start;
        final end = DateTime(
          customDateRange.end.year,
          customDateRange.end.month,
          customDateRange.end.day,
          23, 59, 59
        );
        
        return tasks.where((task) {
          final taskDate = task.createdAt.toLocal();
          return taskDate.isAfter(start.subtract(const Duration(seconds: 1))) && 
                 taskDate.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();
      }
      return tasks;
      
    default:
      return tasks;
  }
}

// Function to initialize real-time subscriptions at app startup
void initializeRealTimeSubscriptions(WidgetRef ref) {
  // Access the provider to initialize it and force refresh
  final notifier = ref.read(realtimeTasksProvider.notifier);
  
  // Make sure Supabase is connected and subscriptions are active
  final supabaseService = ref.read(supabaseServiceProvider);
  
  // Ensure we have an active real-time subscription
  if (!supabaseService.hasActiveTasksSubscription) {
    notifier.refreshTasks();
  }
  
  print('Real-time task subscriptions initialized');
  
  // Schedule periodic refreshes to ensure real-time stays connected
  // This helps with network changes and other connectivity issues
  Timer.periodic(const Duration(minutes: 5), (_) {
    if (!ref.read(supabaseServiceProvider).hasActiveTasksSubscription) {
      print('Re-establishing real-time connection after period check');
      ref.read(realtimeTasksProvider.notifier).refreshTasks();
    }
  });
}

// Stream-based real-time comments notifier
class RealtimeCommentsNotifier extends StateNotifier<List<Comment>> {
  final SupabaseService _supabaseService;
  final String _taskId;
  StreamSubscription<List<Map<String, dynamic>>>? _commentsSubscription;
  bool _disposed = false;
  
  RealtimeCommentsNotifier(this._supabaseService, this._taskId) : super([]) {
    // Initial load of comments
    _loadInitialComments();
    
    // Set up real-time subscription using streams
    _setupStreamSubscription();
  }
  
  Future<void> _loadInitialComments() async {
    if (_disposed) return;
    try {
      final comments = await _supabaseService.getComments(taskId: _taskId);
      if (_disposed) return;
      
      // Sort comments by creation date (oldest first)
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = comments;
      print('Loaded ${comments.length} initial comments for task $_taskId');
    } catch (e) {
      print('Error loading initial comments for task $_taskId: $e');
    }
  }
  
  void _setupStreamSubscription() {
    if (_disposed) return;
    
    try {
      // Create a stream that listens to comments table changes
      final stream = _supabaseService.client
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('task_id', _taskId)
          .order('created_at');
      
      _commentsSubscription = stream.listen(
        (List<Map<String, dynamic>> data) {
          if (_disposed) return;
          
          try {
            final comments = data.map((json) => Comment.fromJson(json)).toList();
            
            // Sort comments by creation date (oldest first)
            comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            
            state = comments;
            
            print('Updated comments via stream for task $_taskId. Total comments: ${comments.length}');
          } catch (e) {
            print('Error processing comments data for task $_taskId: $e');
            // Try to reload comments if there's a processing error
            _loadInitialComments();
          }
        },
        onError: (error) {
          print('Error in comments stream for task $_taskId: $error');
          
          // If there's a stream error, try to reconnect after a delay
          if (!_disposed) {
            Timer(const Duration(seconds: 3), () {
              if (!_disposed) {
                print('Attempting to reconnect comments stream for task $_taskId');
                _commentsSubscription?.cancel();
                _setupStreamSubscription();
              }
            });
          }
        },
        onDone: () {
          print('Comments stream closed for task $_taskId');
          
          // If stream closes unexpectedly, try to reconnect
          if (!_disposed) {
            Timer(const Duration(seconds: 2), () {
              if (!_disposed) {
                print('Reconnecting comments stream for task $_taskId');
                _setupStreamSubscription();
              }
            });
          }
        },
      );
      
      print('Subscribed to real-time comments stream for task $_taskId');
    } catch (e) {
      print('Error setting up comments stream for task $_taskId: $e');
      _commentsSubscription = null;
      
      // Try to reconnect after a delay if setup fails
      if (!_disposed) {
        Timer(const Duration(seconds: 5), () {
          if (!_disposed) {
            print('Retrying comments stream setup for task $_taskId');
            _setupStreamSubscription();
          }
        });
      }
    }
  }
  
  // Public method to manually refresh comments
  Future<void> refreshComments() async {
    await _loadInitialComments();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _commentsSubscription?.cancel();
    _commentsSubscription = null;
    super.dispose();
  }
} 