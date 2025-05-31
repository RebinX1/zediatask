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
  
  // Save FCM token to Supabase
  Future<void> saveToken() async {
    try {
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
      
      // Get the token
      final fcmToken = await _messaging?.getToken();
      if (fcmToken == null) {
        debugPrint('FCM token is null, cannot save');
        return;
      }
      
      // Update the 'users' table with the FCM token
      await supabase
          .from('users')
          .update({
            'notificationtoken': fcmToken,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
      debugPrint('FCM token saved to users table in Supabase');

    } catch (e) {
      debugPrint('Error saving FCM token to users table: $e');
    }
  }

  // Delete FCM token from Supabase (on logout)
  Future<void> deleteToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping token deletion from users table');
        return;
      }
      
      // Clear the FCM token in the 'users' table
      await supabase
          .from('users')
          .update({
            'notificationtoken': null, // Set to null to clear
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
      debugPrint('FCM token cleared from users table in Supabase');
    } catch (e) {
      debugPrint('Error clearing FCM token from users table: $e');
    }
  }
} 