import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMTokenService {
  final SupabaseClient supabase = Supabase.instance.client;
  
  // Use nullable getter to avoid initialization crashes
  FirebaseMessaging? get _messaging {
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('Error accessing FirebaseMessaging.instance: $e');
      return null;
    }
  }
  
  // Save FCM token to users table
  Future<void> saveToken() async {
    try {
      debugPrint('Starting FCM token save process...');
      
      if (_messaging == null) {
        debugPrint('Firebase messaging not available, skipping token storage');
        return;
      }

      // Check if user is authenticated
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping token storage');
        return;
      }
      
      debugPrint('User authenticated: ${user.id}');
      
      // Add a delay to ensure Firebase is fully ready
      await Future.delayed(const Duration(seconds: 1));
      
      // Get the token with better error handling
      String? fcmToken;
      try {
        debugPrint('Attempting to get FCM token...');
        fcmToken = await _messaging!.getToken();
        debugPrint('FCM token retrieved: ${fcmToken != null ? 'SUCCESS' : 'NULL'}');
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
        // If getting token fails, don't proceed with database update
        return;
      }
      
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('FCM token is null or empty, cannot save');
        return;
      }
      
      debugPrint('Saving FCM token to users table: ${fcmToken.substring(0, 20)}...');
      
      // Update the users table with the notification token
      await supabase.from('users').update({
        'notificationtoken': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      
      debugPrint('FCM token saved to users table successfully');
    } catch (e) {
      debugPrint('Error in saveToken process: $e');
    }
  }

  // Delete FCM token from users table (on logout)
  Future<void> deleteToken() async {
    try {
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        await supabase.from('users').update({
          'notificationtoken': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
        
        debugPrint('FCM token cleared from users table');
      }
    } catch (e) {
      debugPrint('Error deleting FCM token from users table: $e');
    }
  }

  // Handle token refresh - update the token in users table
  Future<void> handleTokenRefresh() async {
    try {
      if (_messaging == null) {
        debugPrint('Firebase messaging not available, skipping token refresh handling');
        return;
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        debugPrint('FCM token refreshed: ${newToken.substring(0, 20)}...');
        _saveRefreshedToken(newToken);
      }).onError((err) {
        debugPrint('Error listening to token refresh: $err');
      });
    } catch (e) {
      debugPrint('Error setting up token refresh listener: $e');
    }
  }

  // Private method to save refreshed token
  Future<void> _saveRefreshedToken(String newToken) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping refreshed token storage');
        return;
      }
      
      await supabase.from('users').update({
        'notificationtoken': newToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      
      debugPrint('Refreshed FCM token saved to users table successfully');
    } catch (e) {
      debugPrint('Error saving refreshed FCM token: $e');
    }
  }

  // Method to check Firebase readiness and get token for debugging
  Future<String?> getTokenForDebug() async {
    try {
      if (_messaging == null) {
        debugPrint('Firebase messaging not available');
        return null;
      }

      // Check notification permissions first
      final settings = await _messaging!.getNotificationSettings();
      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('Notifications not authorized');
        return null;
      }

      final token = await _messaging!.getToken();
      debugPrint('Retrieved token for debug: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('Error in getTokenForDebug: $e');
      return null;
    }
  }
} 