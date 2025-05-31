class FirebaseConstants {
  // You need to get this from Firebase Console > Project Settings > Cloud Messaging > Server Key
  // For security, you should store this in environment variables in production
  static const String fcmServerKey = 'AAAA2GxI9-M:APA91bESg4HuZ-6ZR2e3V2DQCEqLqf8uTYXSJbO6VpBctW8q0iRvCRKs8BF1H6LY3CRDwOqXmZH6ub4LN3JXZQ5F5YCeYiQT8H_pJr1vCkZ5qdgEw5r2a4MgfXR6P1T_c6M7yU4NQ9Wm';
  
  // FCM API endpoint
  static const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';
  
  // Project details
  static const String projectId = 'zediatask';
  static const String senderId = '611828740822';
}

// Note: Replace the fcmServerKey above with your actual server key from Firebase Console
// To get your server key:
// 1. Go to Firebase Console (https://console.firebase.google.com/)
// 2. Select your project (zediatask)
// 3. Go to Project Settings (gear icon)
// 4. Click on "Cloud Messaging" tab
// 5. Copy the "Server key" value and replace the placeholder above 