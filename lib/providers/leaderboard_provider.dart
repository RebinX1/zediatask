import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/providers/task_provider.dart';

// Leaderboard provider - now refreshes when tasks are updated and filters by date
final leaderboardProvider = FutureProvider<List<dynamic>>((ref) async {
  // Watch the task update notifier to refresh when tasks are updated
  final lastUpdate = ref.watch(taskUpdateNotifierProvider);
  final now = DateTime.now();
  final difference = now.difference(lastUpdate);
  
  // Get current user role
  final loggedInUser = ref.watch(loggedInUserProvider);
  final isAdmin = loggedInUser?.role == UserRole.admin;
  
  // Watch date filter and date range
  final dateFilter = ref.watch(dateFilterProvider);
  final dateRange = ref.watch(dateRangeProvider);
  
  print('Leaderboard provider - User: ${loggedInUser?.name} (${loggedInUser?.role})');
  print('Leaderboard provider - Date filter: $dateFilter');
  
  // Only log if this is a refresh due to a task update
  if (difference.inMilliseconds < 500) {
    // For admins, don't refresh on every task update
    if (isAdmin) {
      return ref.state.value ?? [];
    }
    print('Leaderboard refreshing due to task update');
  }
  
  final supabaseService = ref.watch(supabaseServiceProvider);
  
  try {
    // Make sure we get data for ALL employees
    print('Fetching leaderboard data from Supabase service...');
    final data = await supabaseService.getLeaderboard();
    print('Leaderboard provider received ${data.length} employees');
    
    if (data.isEmpty) {
      print('WARNING: No employees returned from Supabase service');
      return [];
    }
    
    // Debug output - what employees do we have?
    print('Employees from backend:');
    for (var emp in data) {
      print('- ${emp['name']} (${emp['tasks']?.length ?? 0} tasks)');
    }
    
    // Filter data by date if needed
    final filteredData = _filterLeaderboardByDate(data, dateFilter, dateRange);
    print('After filtering: ${filteredData.length} employees with data in the selected period');
    
    // No further filtering should be needed, return all employees
    return filteredData;
  } catch (e) {
    print('Error in leaderboard provider: $e');
    rethrow;
  }
});

// Helper function to filter leaderboard by date
List<dynamic> _filterLeaderboardByDate(List<dynamic> leaderboardData, DateFilter dateFilter, DateTimeRange? customDateRange) {
  if (dateFilter == DateFilter.all) {
    return leaderboardData;
  }
  
  // Get the start and end dates based on the filter
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime startDate;
  DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  switch (dateFilter) {
    case DateFilter.today:
      startDate = today;
      break;
      
    case DateFilter.thisWeek:
      // Start of week (Monday)
      startDate = today.subtract(Duration(days: today.weekday - 1));
      // End of week (Sunday)
      endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      break;
      
    case DateFilter.thisMonth:
      // First day of current month
      startDate = DateTime(now.year, now.month, 1);
      // Last day of current month
      endDate = (now.month < 12) 
          ? DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1))
          : DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1));
      break;
      
    case DateFilter.custom:
      if (customDateRange != null) {
        startDate = customDateRange.start;
        endDate = DateTime(
          customDateRange.end.year,
          customDateRange.end.month,
          customDateRange.end.day,
          23, 59, 59
        );
      } else {
        return leaderboardData; // No custom range set
      }
      break;
      
    default:
      return leaderboardData;
  }
  
  print('Filtering leaderboard from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
  
  // Reset the leaderboard data with filtered periods
  List<Map<String, dynamic>> filteredData = [];
  
  // For each employee in the original data
  for (var employee in leaderboardData) {
    // Create a filtered copy of the employee
    Map<String, dynamic> filteredEmployee = Map.from(employee);
    
    // We'll recalculate points and tasks
    filteredEmployee['total_points'] = 0;
    filteredEmployee['tasks_completed'] = 0;
    
    // Only include tasks within the date range if we have tasks array
    if (employee.containsKey('tasks') && employee['tasks'] is List) {
      List filteredTasks = [];
      
      for (var task in employee['tasks']) {
        // Check if the task has a completion date
        if (task.containsKey('completed_at') && task['completed_at'] != null) {
          try {
            final completedAt = DateTime.parse(task['completed_at']);
            
            // Check if the completion date is within our filter range
            if (completedAt.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                completedAt.isBefore(endDate.add(const Duration(seconds: 1)))) {
              filteredTasks.add(task);
              
              // Add to total points and tasks count - handle points_awarded as num
              num pointsAwarded = task['points_awarded'] ?? 0;
              filteredEmployee['total_points'] = (filteredEmployee['total_points'] ?? 0) + pointsAwarded;
              filteredEmployee['tasks_completed'] = (filteredEmployee['tasks_completed'] ?? 0) + 1;
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      }
      
      filteredEmployee['tasks'] = filteredTasks;
      print('Filtered employee ${filteredEmployee['name']}: ${filteredEmployee['tasks_completed']} tasks, ${filteredEmployee['total_points']} points');
    }
    
    // Always add the employee to keep them in the list even with zero points/tasks
    filteredData.add(filteredEmployee);
  }
  
  // Sort by total points (highest first)
  filteredData.sort((a, b) => (b['total_points'] ?? 0).compareTo(a['total_points'] ?? 0));
  
  // Print the filtered results
  print('Leaderboard filtered results:');
  for (var employee in filteredData) {
    print('${employee['name']}: ${employee['tasks_completed']} tasks, ${employee['total_points']} points');
  }
  
  return filteredData;
}

// Employee list provider (for task assignment)
final employeesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getEmployees();
}); 