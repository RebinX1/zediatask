import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Use nullable for safer access
  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  
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
      _messaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> initialize() async {
    if (_messaging == null) {
      debugPrint('Skipping notification service initialization: Firebase not available');
      return;
    }
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permission with updated approach for all platforms
      await _requestPermission();
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📱 Foreground message received:');
        debugPrint('📱 Title: ${message.notification?.title}');
        debugPrint('📱 Body: ${message.notification?.body}');
        debugPrint('📱 Data: ${message.data}');
        
        // Show local notification when app is in foreground
        _showLocalNotification(
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? '',
          payload: message.data.toString(),
        );
        
        if (onForegroundMessage != null) {
          onForegroundMessage!(message);
        }
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

  Future<void> _initializeLocalNotifications() async {
    if (_localNotifications == null) return;
    
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/notification_icon');
      
      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Local notification tapped: ${response.payload}');
        },
      );
      
      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );
      
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_localNotifications == null) return;
    
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _localNotifications!.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      
      debugPrint('✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
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

  // Method to show a task notification using local notifications
  Future<void> showTaskNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    debugPrint('📱 NOTIFICATION REQUEST:');
    debugPrint('📱 Title: $title');
    debugPrint('📱 Body: $body');
    debugPrint('📱 Payload: $payload');
    
    // Show the local notification
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload?.toString(),
    );
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