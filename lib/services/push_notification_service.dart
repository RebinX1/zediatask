import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zediatask/constants/firebase_constants.dart';

class PushNotificationService {
  final SupabaseClient supabase = Supabase.instance.client;
  
  // Use Firebase constants for server key and URL
  static String get _serverKey => FirebaseConstants.fcmServerKey;
  static String get _fcmUrl => FirebaseConstants.fcmUrl;

  /// Send push notification to a single user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token from database
      final response = await supabase
          .from('users')
          .select('notificationtoken')
          .eq('id', userId)
          .single();

      final fcmToken = response['notificationtoken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('No FCM token found for user: $userId');
        return false;
      }

      return await _sendNotificationToToken(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('Error sending notification to user $userId: $e');
      return false;
    }
  }

  /// Send push notifications to multiple users
  Future<Map<String, bool>> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final results = <String, bool>{};
    
    try {
      // Get FCM tokens for all users
      final response = await supabase
          .from('users')
          .select('id, notificationtoken')
          .inFilter('id', userIds);

      final users = response as List<dynamic>;
      
      // Send notification to each user with a valid token
      for (final user in users) {
        final userId = user['id'] as String;
        final fcmToken = user['notificationtoken'] as String?;
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
          final success = await _sendNotificationToToken(
            token: fcmToken,
            title: title,
            body: body,
            data: data,
          );
          results[userId] = success;
        } else {
          debugPrint('No FCM token found for user: $userId');
          results[userId] = false;
        }
      }
    } catch (e) {
      debugPrint('Error sending notifications to users: $e');
      // Set all users as failed
      for (final userId in userIds) {
        results[userId] = false;
      }
    }
    
    return results;
  }

  /// Send notification to a specific FCM token
  Future<bool> _sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$_serverKey',
      };

      final payload = {
        'to': token,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': 1,
        },
        'data': data ?? {},
        'priority': 'high',
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final success = responseData['success'] == 1;
        
        if (success) {
          debugPrint('✅ Notification sent successfully');
        } else {
          debugPrint('❌ Notification failed: ${responseData['results']}');
        }
        
        return success;
      } else {
        debugPrint('❌ FCM request failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  /// Send task assignment notifications
  Future<Map<String, bool>> sendTaskAssignmentNotifications({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    bool isGroupTask = false,
  }) async {
    final title = isGroupTask ? 'New Group Task Assigned' : 'New Task Assigned';
    final body = taskTitle;
    
    final data = {
      'taskId': taskId,
      'type': 'task_assigned',
      'isGroupTask': isGroupTask.toString(),
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    };

    return await sendNotificationToUsers(
      userIds: userIds,
      title: title,
      body: body,
      data: data,
    );
  }
} 