import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/services/services.dart';

/// A widget that initializes and handles notifications.
/// Add this to your main widget tree to enable notifications.
class NotificationHandler extends ConsumerStatefulWidget {
  final Widget child;
  
  const NotificationHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<NotificationHandler> createState() => _NotificationHandlerState();
}

class _NotificationHandlerState extends ConsumerState<NotificationHandler> {
  final _fcmTokenService = FCMTokenService();
  bool _initialized = false;
  bool get _isDebugMode => !const bool.fromEnvironment('dart.vm.product');
  
  @override
  void initState() {
    super.initState();
    // Initialize later to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  
  Future<void> _initializeNotifications() async {
    try {
      if (_initialized) return;
      
      // Skip Firebase operations in debug mode
      if (_isDebugMode) {
        debugPrint('Skipping notification initialization in debug mode');
        _initialized = true;
        return;
      }
      
      // Initialize the notification service
      try {
        final taskNotificationService = ref.read(taskNotificationServiceProvider);
        await taskNotificationService.initialize();
        debugPrint('Notification service initialized successfully');
      } catch (e) {
        debugPrint('Error initializing notification service: $e');
        // Continue even if notification service fails
      }
      
      // Try to save FCM token to Supabase but don't block other functionality
      try {
        await _fcmTokenService.saveToken();
        debugPrint('FCM token saved successfully');
      } catch (e) {
        debugPrint('Error saving FCM token (non-critical): $e');
        // Continue even if token storage fails
      }
      
      // Connect tasks to notifications
      try {
        connectTasksToNotifications(ref);
        debugPrint('Tasks connected to notifications');
      } catch (e) {
        debugPrint('Error connecting tasks to notifications: $e');
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error in _initializeNotifications: $e');
      // Don't rethrow as this is a background operation
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is an invisible widget that just handles notifications
    return widget.child;
  }
} 