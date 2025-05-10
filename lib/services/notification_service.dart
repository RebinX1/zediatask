import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // For handling notification when the app is in the background
  final Function(RemoteMessage)? onBackgroundMessage;
  
  // For handling notification when the app is in the foreground
  final Function(RemoteMessage)? onForegroundMessage;
  
  // For handling notification tap
  final Function(RemoteMessage)? onNotificationTap;
  
  NotificationService({
    this.onBackgroundMessage,
    this.onForegroundMessage,
    this.onNotificationTap,
  });

  Future<void> initialize() async {
    // Request permission with updated approach for all platforms
    await _requestPermission();
    
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (onForegroundMessage != null) {
        onForegroundMessage!(message);
      }
      debugPrint('📱 Foreground message received:');
      debugPrint('📱 Title: ${message.notification?.title}');
      debugPrint('📱 Body: ${message.notification?.body}');
      debugPrint('📱 Data: ${message.data}');
    });
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (onNotificationTap != null) {
        onNotificationTap!(message);
      }
      debugPrint('📱 Background message tapped:');
      debugPrint('📱 Title: ${message.notification?.title}');
      debugPrint('📱 Body: ${message.notification?.body}');
    });
    
    // Check for initial notification (if app was opened from notification)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && onNotificationTap != null) {
      onNotificationTap!(initialMessage);
      debugPrint('📱 Initial message handled:');
      debugPrint('📱 Title: ${initialMessage.notification?.title}');
      debugPrint('📱 Body: ${initialMessage.notification?.body}');
    }
  }

  Future<void> _requestPermission() async {
    // Request permissions for iOS, new approach works for Android 13+ too
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
      announcement: false,
      carPlay: false,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');
    
    // For iOS foreground notification presentation
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Subscribe to topic for testing
    await FirebaseMessaging.instance.subscribeToTopic('all');
    debugPrint('Subscribed to "all" topic for testing notifications');
  }

  // Method to manually show a task notification using FCM API
  Future<void> showTaskNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    // Log the notification - since we can't directly send local notifications 
    // without flutter_local_notifications, this is mainly for debugging
    debugPrint('📱 NOTIFICATION REQUEST:');
    debugPrint('📱 Title: $title');
    debugPrint('📱 Body: $body');
    debugPrint('📱 Payload: $payload');
    
    // This method won't actually show a notification without a server
    // For production, you would implement server-side notifications using Firebase Cloud Messaging
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    return token;
  }

  Future<void> subscribeTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
} 