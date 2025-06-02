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
      
      // Get basic device info
      final deviceInfo = {
        'platform': 'flutter',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Check if token already exists for this user
      final existingTokens = await supabase
          .from('user_tokens')
          .select()
          .eq('user_id', user.id)
          .eq('fcm_token', fcmToken);
      
      if (existingTokens.isEmpty) {
        // Insert new token
        await supabase.from('user_tokens').insert({
          'user_id': user.id,
          'fcm_token': fcmToken,
          'device_info': deviceInfo,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('FCM token saved to user_tokens table in Supabase');
      } else {
        // Update existing token
        await supabase
            .from('user_tokens')
            .update({
              'device_info': deviceInfo, 
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('user_id', user.id)
            .eq('fcm_token', fcmToken);
        debugPrint('FCM token updated in user_tokens table in Supabase');
      }

    } catch (e) {
      debugPrint('Error saving FCM token to user_tokens table: $e');
    }
  }

  // Delete FCM token from Supabase (on logout)
  Future<void> deleteToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping token deletion from user_tokens table');
        return;
      }
      
      final fcmToken = await _messaging?.getToken();
      if (fcmToken != null) {
        // Delete the specific token for this user and device
        await supabase
            .from('user_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('fcm_token', fcmToken);
        debugPrint('FCM token deleted from user_tokens table in Supabase');
      } else {
        // If we can't get the current token, delete all tokens for this user
        await supabase
            .from('user_tokens')
            .delete()
            .eq('user_id', user.id);
        debugPrint('All FCM tokens deleted for user from user_tokens table in Supabase');
      }
    } catch (e) {
      debugPrint('Error clearing FCM token from user_tokens table: $e');
    }
  }
} 