import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/utils/app_theme.dart';

class LeaderboardTab extends ConsumerWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final selectedDateFilter = ref.watch(dateFilterProvider);
    final loggedInUser = ref.watch(loggedInUserProvider);
    
    print('Leaderboard tab building - User: ${loggedInUser?.name} (${loggedInUser?.role})');
    print('Leaderboard tab - Date filter: $selectedDateFilter');
    
    return Column(
      children: [
        // Date filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip(
                  context,
                  ref,
                  label: 'All Time',
                  value: DateFilter.all,
                  selectedFilter: selectedDateFilter,
                ),
                const SizedBox(width: 8),
                _buildDateFilterChip(
                  context,
                  ref,
                  label: 'Today',
                  value: DateFilter.today,
                  selectedFilter: selectedDateFilter,
                ),
                const SizedBox(width: 8),
                _buildDateFilterChip(
                  context,
                  ref,
                  label: 'This Week',
                  value: DateFilter.thisWeek,
                  selectedFilter: selectedDateFilter,
                ),
                const SizedBox(width: 8),
                _buildDateFilterChip(
                  context,
                  ref,
                  label: 'This Month',
                  value: DateFilter.thisMonth,
                  selectedFilter: selectedDateFilter,
                ),
                const SizedBox(width: 8),
                _buildCustomDateFilterChip(
                  context,
                  ref,
                  selectedFilter: selectedDateFilter,
                ),
              ],
            ),
          ),
        ),
        
        // Leaderboard content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Force a complete refresh
              ref.refresh(dateFilterProvider);
              ref.refresh(leaderboardProvider);
            },
            child: leaderboardAsync.when(
              data: (leaderboardData) {
                print('Leaderboard tab received ${leaderboardData.length} employees');
                
                if (leaderboardData.isEmpty) {
                  return _buildEmptyState(context);
                }
                
                // Debug output - what employees do we have?
                print('Employees in UI:');
                for (var emp in leaderboardData) {
                  print('- ${emp['name']} (${emp['tasks']?.length ?? 0} tasks, ${emp['total_points'] ?? 0} points)');
                }
                
                // Check if there's any data with points in the selected date range
                bool hasActiveData = leaderboardData.any((employee) => 
                  (employee['total_points'] ?? 0) > 0);
                
                if (!hasActiveData && selectedDateFilter != DateFilter.all) {
                  // Still show the leaderboard but with a message
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: AppTheme.textLightColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No leaderboard data for selected date range',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(dateFilterProvider.notifier).state = DateFilter.all;
                            },
                            child: const Text('Show All Time'),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  );
                }
                
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopPerformers(context, leaderboardData),
                      const SizedBox(height: 24),
                      _buildLeaderboardTable(context, leaderboardData),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required DateFilter value,
    required DateFilter selectedFilter,
  }) {
    final isSelected = value == selectedFilter;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (isSelected) {
        ref.read(dateFilterProvider.notifier).state = isSelected ? value : DateFilter.all;
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCustomDateFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required DateFilter selectedFilter,
  }) {
    final isSelected = DateFilter.custom == selectedFilter;
    final dateRange = ref.watch(dateRangeProvider);
    
    String label = 'Custom';
    if (isSelected && dateRange != null) {
      final start = dateRange.start;
      final end = dateRange.end;
      label = '${start.day}/${start.month} - ${end.day}/${end.month}';
    }
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (isSelected) async {
        if (isSelected) {
          // Show date range picker
          final selectedRange = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: dateRange ?? DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    onSurface: AppTheme.textPrimaryColor,
                  ),
                ),
                child: child!,
              );
            },
          );
          
          if (selectedRange != null) {
            ref.read(dateRangeProvider.notifier).state = selectedRange;
            ref.read(dateFilterProvider.notifier).state = DateFilter.custom;
          } else {
            // If user cancels, revert to All
            ref.read(dateFilterProvider.notifier).state = DateFilter.all;
          }
        } else {
          // Deselect custom filter
          ref.read(dateFilterProvider.notifier).state = DateFilter.all;
        }
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 64,
            color: AppTheme.textLightColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No leaderboard data available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers(BuildContext context, List<dynamic> leaderboardData) {
    // Filter to only include users with points
    final activeUsers = leaderboardData.where((user) => (user['total_points'] ?? 0) > 0).toList();
    
    // Only show top 3 users with points
    final top3 = activeUsers.take(3).toList();
    
    if (top3.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No top performers for selected date range',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (top3.length > 1)
              _buildTopPerformerItem(
                context,
                rank: 2,
                name: top3[1]['name'] ?? 'Unknown',
                points: top3[1]['total_points'] ?? 0,
                tasksCompleted: top3[1]['tasks_completed'] ?? 0,
              ),
            
            if (top3.isNotEmpty)
              _buildTopPerformerItem(
                context,
                rank: 1,
                name: top3[0]['name'] ?? 'Unknown',
                points: top3[0]['total_points'] ?? 0,
                tasksCompleted: top3[0]['tasks_completed'] ?? 0,
                isTop: true,
              ),
            
            if (top3.length > 2)
              _buildTopPerformerItem(
                context,
                rank: 3,
                name: top3[2]['name'] ?? 'Unknown',
                points: top3[2]['total_points'] ?? 0,
                tasksCompleted: top3[2]['tasks_completed'] ?? 0,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPerformerItem(
    BuildContext context, {
    required int rank,
    required String name,
    required int points,
    required int tasksCompleted,
    bool isTop = false,
  }) {
    // Colors for different rankings
    final colors = {
      1: const Color(0xFFFFD700), // Gold
      2: const Color(0xFFC0C0C0), // Silver
      3: const Color(0xFFCD7F32), // Bronze
    };

    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isTop ? 80 : 70,
                height: isTop ? 80 : 70,
                decoration: BoxDecoration(
                  color: colors[rank]?.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors[rank] ?? AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: colors[rank],
                      fontSize: isTop ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (isTop)
                Positioned(
                  top: 0,
                  child: Icon(
                    Icons.emoji_events,
                    color: colors[rank],
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTop ? 16 : 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$points pts',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
              fontSize: isTop ? 14 : 12,
            ),
          ),
          Text(
            '$tasksCompleted tasks',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: isTop ? 12 : 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTable(BuildContext context, List<dynamic> leaderboardData) {
    // Filter to only include users with points
    final activeUsers = leaderboardData.where((user) => (user['total_points'] ?? 0) > 0).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leaderboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (activeUsers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No users have completed tasks in this time period',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Name',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Points',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Tasks',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Table rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeUsers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final employee = activeUsers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: index < 3
                                    ? [
                                        const Color(0xFFFFD700),
                                        const Color(0xFFC0C0C0),
                                        const Color(0xFFCD7F32),
                                      ][index]
                                    : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              employee['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${employee['total_points'] ?? 0}',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${employee['tasks_completed'] ?? 0}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
} 