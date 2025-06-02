import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMEdgeFunctionService {
  final SupabaseClient supabase = Supabase.instance.client;
  
  // Supabase edge function endpoint
  static const String _edgeFunctionUrl = 'https://yfwyucrgqjalwztolnbq.supabase.co/functions/v1/send-fcm';

  /// Send push notification to a single user using their user ID
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get user's FCM token from user_tokens table
      final response = await supabase
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['fcm_token'] == null) {
        debugPrint('No FCM token found for user: $userId');
        return false;
      }

      final fcmToken = response['fcm_token'] as String;
      
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

  /// Send push notifications to multiple users using their user IDs
  Future<Map<String, bool>> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final results = <String, bool>{};
    
    try {
      // Get FCM tokens for all users
      final response = await supabase
          .from('user_tokens')
          .select('user_id, fcm_token')
          .inFilter('user_id', userIds);

      final userTokens = response as List<dynamic>;
      
      // Send notification to each user with a valid token
      for (final userToken in userTokens) {
        final userId = userToken['user_id'] as String;
        final fcmToken = userToken['fcm_token'] as String?;
        
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
      
      // Handle users that don't have tokens in the user_tokens table
      final foundUserIds = userTokens.map((ut) => ut['user_id'] as String).toSet();
      for (final userId in userIds) {
        if (!foundUserIds.contains(userId)) {
          debugPrint('No FCM token record found for user: $userId');
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

  /// Send notification to a specific FCM token using the edge function
  Future<bool> _sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get the auth token for Supabase
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint('❌ No active session for sending notification');
        return false;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };

      final payload = {
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
      };

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final success = responseData['success'] == true;
        
        if (success) {
          debugPrint('✅ Notification sent successfully via edge function');
          debugPrint('✅ Message ID: ${responseData['messageId']}');
        } else {
          debugPrint('❌ Notification failed via edge function: ${responseData['error']}');
        }
        
        return success;
      } else {
        debugPrint('❌ Edge function request failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM notification via edge function: $e');
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

  /// Send task update notifications
  Future<Map<String, bool>> sendTaskUpdateNotifications({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String updateType,
  }) async {
    final title = 'Task Updated';
    final body = '$updateType: $taskTitle';
    
    final data = {
      'taskId': taskId,
      'type': 'task_updated',
      'updateType': updateType,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    };

    return await sendNotificationToUsers(
      userIds: userIds,
      title: title,
      body: body,
      data: data,
    );
  }

  /// Send task completion notifications
  Future<Map<String, bool>> sendTaskCompletionNotifications({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String completedBy,
  }) async {
    final title = 'Task Completed';
    final body = '$taskTitle has been completed by $completedBy';
    
    final data = {
      'taskId': taskId,
      'type': 'task_completed',
      'completedBy': completedBy,
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