class AppConstants {
  // Supabase
  static const String supabaseUrl = 'https://yfwyucrgqjalwztolnbq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlmd3l1Y3JncWphbHd6dG9sbmJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyNDgxNTAsImV4cCI6MjA1NjgyNDE1MH0.iRkwsMfxJcGoOZhke00pZLUc2DX7gPUNFPffZGtSxG4';

  // Task Priorities
  static const Map<String, String> taskPriorityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };

  // Task Status
  static const Map<String, String> taskStatusLabels = {
    'pending': 'Pending',
    'accepted': 'Accepted',
    'completed': 'Completed',
  };
  
  // Points System
  static const int pointsFastAcceptance = 5; // Within an hour
  static const int pointsNormalAcceptance = 2; // Within a day
  static const int pointsCompletionBeforeDeadline = 10;
  static const int pointsCompletionOnTime = 5;
  static const int pointsBasicCompletion = 2;
} 