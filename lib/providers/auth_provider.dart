import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:zediatask/models/models.dart';
import 'package:zediatask/services/services.dart';
import 'package:zediatask/providers/task_provider.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// Authentication state provider
final isAuthenticatedProvider = StateProvider<bool>((ref) {
  final client = Supabase.instance.client;
  return client.auth.currentUser != null;
});

// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  try {
    final supabaseService = ref.read(supabaseServiceProvider);
    final user = await supabaseService.currentUser;
    return user;
  } catch (e) {
    print('Error fetching current user: $e');
    return null;
  }
});

// Current logged in user state (for preserving login state)
final loggedInUserProvider = StateProvider<User?>((ref) => null);

// User role provider
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  // First check if we have a user in the state provider
  final loggedInUser = ref.watch(loggedInUserProvider);
  if (loggedInUser != null) {
    return loggedInUser.role;
  }
  
  // Fall back to checking from the server
  final user = await ref.watch(currentUserProvider.future);
  return user?.role ?? UserRole.employee;
});

// User details provider
final userDetailsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Watch the task update notifier to refresh when tasks are updated
  // Only check if the value is newer than 500ms ago to avoid infinite refreshes
  final lastUpdate = ref.watch(taskUpdateNotifierProvider);
  final now = DateTime.now();
  final difference = now.difference(lastUpdate);
  
  // Only log if this is a refresh due to a task update
  if (difference.inMilliseconds < 500) {
    print('User details refreshing due to task update');
  }
  
  // First check if we have a user in the state provider
  final loggedInUser = ref.watch(loggedInUserProvider);
  if (loggedInUser != null) {
    // If we have a logged in user, get fresh user data from the database
    // This ensures we have the latest points and stats
    try {
      // Only fetch fresh data from server if:
      // 1. This is due to a task update (difference < 500ms) AND the user is an employee (not admin/manager)
      // 2. OR this is the first time loading the data or it's been more than 5 minutes
      bool shouldRefresh = (difference.inMilliseconds < 500 && loggedInUser.role == UserRole.employee) || 
                           difference.inMinutes > 5;
      
      if (shouldRefresh) {
        final client = Supabase.instance.client;
        final freshUserData = await client
          .from('users')
          .select()
          .eq('id', loggedInUser.id)
          .single();
        
        // Update our user object with fresh data
        final updatedUser = User.fromJson(freshUserData);
        
        // Update the logged in user state with fresh data
        ref.read(loggedInUserProvider.notifier).state = updatedUser;
        
        print('Refreshed user details for ${updatedUser.name}');
        
        return {
          'id': updatedUser.id,
          'name': updatedUser.name,
          'email': updatedUser.email,
          'role': updatedUser.role.toStringValue(),
          'total_points': updatedUser.totalPoints ?? 0,
          'tasks_completed': updatedUser.tasksCompleted ?? 0,
          'avg_completion_time': updatedUser.avgCompletionTime ?? 0.0,
        };
      }
      
      // Otherwise use cached user data
      return {
        'id': loggedInUser.id,
        'name': loggedInUser.name,
        'email': loggedInUser.email,
        'role': loggedInUser.role.toStringValue(),
        'total_points': loggedInUser.totalPoints ?? 0,
        'tasks_completed': loggedInUser.tasksCompleted ?? 0,
        'avg_completion_time': loggedInUser.avgCompletionTime ?? 0.0,
      };
    } catch (e) {
      print('Error refreshing user data: $e');
      // Fall back to cached user data if refresh fails
      return {
        'id': loggedInUser.id,
        'name': loggedInUser.name,
        'email': loggedInUser.email,
        'role': loggedInUser.role.toStringValue(),
        'total_points': loggedInUser.totalPoints ?? 0,
        'tasks_completed': loggedInUser.tasksCompleted ?? 0,
        'avg_completion_time': loggedInUser.avgCompletionTime ?? 0.0,
      };
    }
  }
  
  // Fall back to checking from the server
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  
  return {
    'id': user.id,
    'name': user.name,
    'email': user.email,
    'role': user.role.toStringValue(),
    'total_points': user.totalPoints ?? 0,
    'tasks_completed': user.tasksCompleted ?? 0,
    'avg_completion_time': user.avgCompletionTime ?? 0.0,
  };
}); 