# Notification Implementation Guide

This guide explains how to set up and manage notifications in the ZediaTask app.

## Current Implementation Status

The app already has:
- ✅ Firebase Core dependency configured in pubspec.yaml
- ✅ Firebase initialization in main.dart
- ✅ NotificationHandler component wrapping the app
- ✅ Custom notification icon in the drawable folder
- ✅ Android permissions in the AndroidManifest.xml
- ✅ Local notification service implementation
- ✅ Task notification service implementation

## Firebase Project Setup

To enable push notifications, you need to create a Firebase project and connect it to your app:

1. **Create a Firebase project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project" and follow the setup wizard
   - Enter a project name (e.g., "ZediaTask")
   - Enable/disable Google Analytics as desired
   - Click "Create project"

2. **Add Android app to Firebase project**:
   - In your Firebase project, click the Android icon to add an Android app
   - Enter the package name from your AndroidManifest.xml (e.g., "com.example.zediatask")
   - Enter a nickname for the app (e.g., "ZediaTask Android")
   - Add the SHA-1 certificate (optional for notifications, required for Google Sign-In)
   - Click "Register app"

3. **Download and add google-services.json**:
   - Download the google-services.json file
   - Place it in the android/app/ directory of your Flutter project

4. **Update build.gradle files**:
   - Ensure your android/build.gradle has Firebase plugins:
     ```gradle
     buildscript {
         dependencies {
             // ... other dependencies
             classpath 'com.google.gms:google-services:4.3.15'
         }
     }
     ```
   - Ensure your android/app/build.gradle applies the plugin:
     ```gradle
     apply plugin: 'com.android.application'
     apply plugin: 'kotlin-android'
     apply plugin: 'com.google.gms.google-services'
     ```

## Storing FCM Tokens in Supabase

To enable targeting specific users with notifications, you should store Firebase Cloud Messaging (FCM) tokens in Supabase:

1. **Create a table in Supabase**:
   - Navigate to your Supabase project
   - Go to Table Editor
   - Create a new table called "user_tokens" with the following columns:
     - id (uuid, primary key)
     - user_id (uuid, foreign key to auth.users, not null)
     - fcm_token (text, not null)
     - device_info (jsonb, nullable)
     - created_at (timestamp with time zone, default: now())
     - updated_at (timestamp with time zone, default: now())

2. **Create RLS policies**:
   - Allow users to insert and update only their own tokens:
     ```sql
     CREATE POLICY "Users can insert their own tokens" ON "public"."user_tokens"
     FOR INSERT WITH CHECK (auth.uid() = user_id);
     
     CREATE POLICY "Users can update their own tokens" ON "public"."user_tokens"
     FOR UPDATE USING (auth.uid() = user_id);
     ```

3. **Add token storage to your app**:

Create a new file `lib/services/fcm_token_service.dart`:

```dart
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
      
      // Get basic device info
      final deviceInfo = {
        'platform': Theme.of(Supabase.instance.client.auth.currentSession?.device),
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
```

4. **Initialize token storage in your app**:

In the NotificationHandler class, add the token storage:

```dart
import 'package:zediatask/services/fcm_token_service.dart';

class _NotificationHandlerState extends ConsumerState<NotificationHandler> {
  final _fcmTokenService = FCMTokenService();
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
  
  Future<void> _initializeNotifications() async {
    // Initialize the notification service
    final taskNotificationService = ref.read(taskNotificationServiceProvider);
    await taskNotificationService.initialize();
    
    // Save FCM token to Supabase
    await _fcmTokenService.saveToken();
    
    // Connect tasks to notifications
    connectTasksToNotifications(ref);
  }
  
  // Rest of the code...
}
```

## Sending Server-Side Notifications

To send notifications from your server to specific users:

1. Create a Supabase Edge Function or server-side script
2. Fetch FCM tokens for target users
3. Use Firebase Admin SDK to send push notifications

Example server-side code (Node.js with Firebase Admin):

```js
// Edge function or server code
import { createClient } from '@supabase/supabase-js';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  }),
});

// Initialize Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export const sendTaskNotification = async (userId, taskId, taskTitle) => {
  try {
    // Get user's FCM tokens
    const { data: tokenData, error } = await supabase
      .from('user_tokens')
      .select('fcm_token')
      .eq('user_id', userId);
    
    if (error || !tokenData.length) {
      console.error('No tokens found for user:', userId);
      return { success: false, error: 'No tokens found' };
    }
    
    // Extract tokens
    const tokens = tokenData.map(t => t.fcm_token);
    
    // Send notification to each token
    const message = {
      notification: {
        title: 'New Task Assigned',
        body: taskTitle,
      },
      data: {
        taskId: taskId,
        type: 'task_assigned',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: tokens,
    };
    
    const response = await admin.messaging().sendMulticast(message);
    console.log('Successfully sent notifications:', response.successCount);
    
    return { success: true, sentCount: response.successCount };
  } catch (error) {
    console.error('Error sending notification:', error);
    return { success: false, error: error.message };
  }
};
```

## Testing Notifications

To test notifications locally:

1. Run the app on a physical device or emulator with Google Play Services
2. Use Firebase Console to send a test message:
   - Go to Firebase Console > Your Project > Engage > Messaging
   - Click "Send your first message"
   - Create a notification with a title and body
   - Under "Additional options" > "Target", select "Single device"
   - Enter the FCM token from your device (you can print it in your app)
   - Complete the setup and send the message

## Troubleshooting

- If notifications don't appear, check:
  - Firebase is properly initialized
  - Token is being generated (via `FirebaseMessaging.instance.getToken()`)
  - Android Manifest has all required permissions
  - The device is connected to the internet
  - Background message handler is registered properly 