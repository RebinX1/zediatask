import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Use nullable for safer access
  FirebaseMessaging? _messaging;
  bool _isDebugMode = !const bool.fromEnvironment('dart.vm.product');
  
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
  }) {
    // Initialize in constructor with safe access
    try {
      if (!_isDebugMode) {
        _messaging = FirebaseMessaging.instance;
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> initialize() async {
    // Skip in debug mode
    if (_isDebugMode || _messaging == null) {
      debugPrint('Skipping notification service initialization: Firebase not available or in debug mode');
      return;
    }
    
    try {
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
    } catch (e) {
      debugPrint('Error during notification service initialization: $e');
    }
  }

  Future<void> _requestPermission() async {
    if (_messaging == null) return;
    
    try {
      // Request permissions for iOS, new approach works for Android 13+ too
      final settings = await _messaging!.requestPermission(
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
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
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
    if (_messaging == null) return null;
    
    try {
      final token = await _messaging!.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> subscribeTopic(String topic) async {
    if (_messaging == null) return;
    
    try {
      await _messaging!.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeTopic(String topic) async {
    if (_messaging == null) return;
    
    try {
      await _messaging!.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
} 