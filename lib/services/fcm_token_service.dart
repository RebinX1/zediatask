import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMTokenService {
  final SupabaseClient supabase = Supabase.instance.client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // Save FCM token to Supabase
  Future<void> saveToken() async {
    try {
      // Check if user is authenticated
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping token storage');
        return;
      }
      
      // Get the token
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('FCM token is null, cannot save');
        return;
      }
      
      // Get basic device info - just use simple values to avoid schema errors
      final deviceInfo = {
        'platform': 'android',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Check if token already exists
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
        });
        debugPrint('FCM token saved to Supabase');
      } else {
        // Update existing token
        await supabase
            .from('user_tokens')
            .update({'device_info': deviceInfo, 'updated_at': DateTime.now().toIso8601String()})
            .eq('user_id', user.id)
            .eq('fcm_token', fcmToken);
        debugPrint('FCM token updated in Supabase');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Delete FCM token from Supabase (on logout)
  Future<void> deleteToken() async {
    try {
      final user = supabase.auth.currentUser;
      final fcmToken = await _messaging.getToken();
      
      if (user != null && fcmToken != null) {
        await supabase
            .from('user_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('fcm_token', fcmToken);
        debugPrint('FCM token deleted from Supabase');
      }
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
} 