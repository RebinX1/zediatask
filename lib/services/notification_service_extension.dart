import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/notification_provider.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/services/notification_service.dart';

// Task notification service provider
final taskNotificationServiceProvider = Provider<TaskNotificationService>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return TaskNotificationService(notificationService: notificationService);
});

class TaskNotificationService {
  final NotificationService notificationService;
  
  TaskNotificationService({required this.notificationService});
  
  // Initialize the service
  Future<void> initialize() async {
    await notificationService.initialize();
  }
  
  // Show notification for a new task
  Future<void> showNewTaskNotification(Task task) async {
    final title = 'New Task: ${task.title}';
    final body = task.description.length > 100 
        ? '${task.description.substring(0, 97)}...' 
        : task.description;
        
    await notificationService.showTaskNotification(
      title: title,
      body: body,
      payload: {
        'taskId': task.id,
        'type': 'new_task',
      },
    );
  }
  
  // Show notification for task assigned to user
  Future<void> showTaskAssignedNotification(Task task) async {
    final title = 'Task Assigned to You';
    final body = task.title;
        
    await notificationService.showTaskNotification(
      title: title,
      body: body,
      payload: {
        'taskId': task.id,
        'type': 'task_assigned',
      },
    );
  }
  
  // Show notification for task update
  Future<void> showTaskUpdatedNotification(Task task) async {
    final title = 'Task Updated';
    final body = task.title;
        
    await notificationService.showTaskNotification(
      title: title,
      body: body,
      payload: {
        'taskId': task.id,
        'type': 'task_updated',
      },
    );
  }
}

// Connect task streams to notifications - call this when initializing app
void connectTasksToNotifications(WidgetRef ref) {
  // Listen to real-time task streams using StateNotifierProvider directly
  ref.listen<List<Task>>(
    realtimeTasksProvider, 
    (previous, current) {
      // Handle changes to tasks
      if (previous == null) return; // Skip first change
      
      // If the current list has more tasks than before
      if (current.length > previous.length) {
        // Find the new tasks (those in current but not in previous)
        final previousTaskIds = previous.map((t) => t.id).toSet();
        final addedTasks = current.where((task) => !previousTaskIds.contains(task.id)).toList();
        
        // Show notifications for new tasks
        if (addedTasks.isNotEmpty) {
          final taskNotificationService = ref.read(taskNotificationServiceProvider);
          for (final task in addedTasks) {
            taskNotificationService.showNewTaskNotification(task);
            debugPrint('📱 Showing notification for new task: ${task.title}');
          }
        }
      }
    },
  );
  
  // Also listen to the taskNotificationSubject using the StreamProvider
  ref.listen(
    taskNotificationStreamProvider,
    (previous, current) {
      current.whenData((notificationData) {
        if (notificationData.containsKey('task')) {
          final task = notificationData['task'] as Task;
          final taskNotificationService = ref.read(taskNotificationServiceProvider);
          taskNotificationService.showNewTaskNotification(task);
          debugPrint('📱 Showing notification from stream for task: ${task.title}');
        }
      });
    },
  );
} 