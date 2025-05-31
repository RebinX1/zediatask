# Push Notification Setup Guide

## Overview
Your ZediaTask app now has push notification functionality integrated into the create task screen. When you create a task and assign it to users, the app will automatically send push notifications to those users.

## Current Implementation Status

✅ **Completed:**
- Push notification service created (`lib/services/push_notification_service.dart`)
- Integration with create task screen
- Support for both single user and group task notifications
- FCM token storage in Supabase users table
- HTTP package dependency added

⚠️ **Requires Configuration:**
- Firebase Server Key needs to be updated with your actual key

## Getting Your Firebase Server Key

To enable push notifications, you need to get the server key from your Firebase project:

### Step 1: Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your `zediatask` project

### Step 2: Get Server Key
1. Click on the **Settings** gear icon (⚙️) in the left sidebar
2. Select **Project settings**
3. Click on the **Cloud Messaging** tab
4. Under **Project credentials**, you'll find:
   - **Server key** - This is what you need
   - **Sender ID** - Already configured (611828740822)

### Step 3: Update the Code
Replace the placeholder server key in `lib/constants/firebase_constants.dart`:

```dart
class FirebaseConstants {
  // Replace with your actual server key from Firebase Console
  static const String fcmServerKey = 'YOUR_ACTUAL_SERVER_KEY_HERE';
  
  // These are already correct
  static const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';
  static const String projectId = 'zediatask';
  static const String senderId = '611828740822';
}
```

## How It Works

### When Creating a Task:

1. **Single User Task:**
   - Select an employee from the dropdown
   - Create the task
   - App automatically sends a push notification to that user

2. **Group Task:**
   - Select multiple employees using checkboxes
   - Create the task
   - App sends push notifications to all selected users

### Notification Details:
- **Title:** "New Task Assigned" or "New Group Task Assigned"
- **Body:** The task title
- **Data:** Includes task ID, type, and other metadata for handling taps

## Testing the Notifications

### Prerequisites:
1. Update the Firebase server key as described above
2. Ensure users have FCM tokens saved (they should auto-save when users log in)
3. Test on a physical device (notifications don't work well on simulators)

### Testing Steps:
1. Log in as an admin or manager
2. Go to create task screen
3. Fill in task details
4. Select one or more employees
5. Create the task
6. The selected users should receive push notifications immediately

### Debugging:
Check the console logs for:
- `✅ Notification sent successfully` - notification was sent
- `❌ Notification failed` - check the error details
- `No FCM token found for user` - user needs to log in to generate a token

## Security Considerations

### Production Setup:
1. **Never commit server keys to version control**
2. **Use environment variables:**
   ```dart
   static const String fcmServerKey = String.fromEnvironment('FCM_SERVER_KEY');
   ```
3. **Consider using Firebase Admin SDK on a server instead of client-side HTTP calls**

### Current Setup:
- The server key is stored in the code (for development)
- In production, move this to environment variables or server-side implementation

## Notification Flow

```
Create Task → Get User IDs → Fetch FCM Tokens → Send HTTP Request to FCM → Users Receive Notifications
```

## Error Handling

The app includes comprehensive error handling:
- Failed notifications don't prevent task creation
- Users see success messages when notifications are sent
- Console logs provide debugging information
- Missing FCM tokens are handled gracefully

## Features

### Supported Notification Types:
- ✅ Task assignment (single user)
- ✅ Group task assignment (multiple users)
- 🔄 Task updates (can be added later)
- 🔄 Task completion reminders (can be added later)

### Current Limitations:
- Requires Firebase server key configuration
- Client-side HTTP calls (consider server-side for production)
- Basic notification payload (can be enhanced)

## Next Steps

1. **Get and configure your Firebase server key**
2. **Test notifications on physical devices**
3. **Consider implementing server-side notifications for production**
4. **Add more notification types (updates, reminders, etc.)**

## Support

If you encounter issues:
1. Check Firebase Console for project configuration
2. Verify FCM tokens are being saved to Supabase
3. Test with the Firebase Console messaging feature first
4. Check device notification permissions 