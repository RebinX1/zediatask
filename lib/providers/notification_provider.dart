import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/services/services.dart';

// FCM Edge Function service provider
final fcmEdgeFunctionServiceProvider = Provider<FCMEdgeFunctionService>((ref) {
  return FCMEdgeFunctionService();
});

// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    onForegroundMessage: (message) {
      // Handle foreground message
      final title = message.notification?.title ?? 'New Notification';
      final body = message.notification?.body ?? '';
      
      // Update in-app notification state
      ref.read(lastNotificationProvider.notifier).state = title;
      ref.read(notificationCountProvider.notifier).state += 1;
    },
    onNotificationTap: (message) {
      // Handle notification tap - could navigate to specific task
      print('Notification tapped: ${message.notification?.title}');
    },
  );
});

// Simple in-app notification provider
final notificationCountProvider = StateProvider<int>((ref) => 0);

// Last notification message provider
final lastNotificationProvider = StateProvider<String?>((ref) => null);

// Show an in-app notification
void showInAppNotification(WidgetRef ref, String message) {
  ref.read(notificationCountProvider.notifier).state += 1;
  ref.read(lastNotificationProvider.notifier).state = message;
}

// Show a task notification
Future<void> showTaskNotification(WidgetRef ref, {
  required String title,
  required String body,
  Task? task,
}) async {
  // Show local notification
  final notificationService = ref.read(notificationServiceProvider);
  
  await notificationService.showTaskNotification(
    title: title,
    body: body,
    payload: task != null ? {
      'taskId': task.id,
      'taskTitle': task.title,
    } : null,
  );
  
  // Also update in-app notification state
  ref.read(lastNotificationProvider.notifier).state = title;
  ref.read(notificationCountProvider.notifier).state += 1;
}

// Clear notifications count
void clearNotifications(WidgetRef ref) {
  ref.read(notificationCountProvider.notifier).state = 0;
} 