import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/utils/date_formatter.dart';
import 'package:zediatask/widgets/task_card.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user role
    final loggedInUser = ref.watch(loggedInUserProvider);
    final isAdmin = loggedInUser?.role == UserRole.admin;
    
    // For non-admin users, watch the task update notifier to refresh when tasks are updated
    if (!isAdmin) {
      final lastUpdate = ref.watch(taskUpdateNotifierProvider);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      
      // Only log if this is a refresh due to a task update
      if (difference.inMilliseconds < 500) {
        print('Dashboard refreshing due to task update: ${difference.inMilliseconds}ms ago');
      }
    }
    
    final userTasksAsync = ref.watch(userTasksProvider);
    final userDetailsAsync = ref.watch(userDetailsProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(userTasksProvider);
        ref.refresh(userDetailsProvider);
      },
      color: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            userDetailsAsync.when(
              data: (userDetails) {
                if (userDetails == null) {
                  return const SizedBox.shrink();
                }
                return _WelcomeSection(name: userDetails['name'] ?? 'User');
              },
              loading: () => const _WelcomeSection(name: 'User'),
              error: (_, __) => const _WelcomeSection(name: 'User'),
            ),
            
            // Task statistics
            userTasksAsync.when(
              data: (tasks) => _TaskStatistics(tasks: tasks),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading tasks',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.refresh(userTasksProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            
            // Tasks sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Tasks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            
            userTasksAsync.when(
              data: (tasks) {
                final pendingTasks = tasks
                    .where((task) => task.status == TaskStatus.pending)
                    .toList();
                
                if (pendingTasks.isEmpty) {
                  return _EmptyTasksPlaceholder(
                    message: 'No pending tasks',
                    icon: Icons.check_circle_outline,
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingTasks.length > 3 ? 3 : pendingTasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TaskCard(task: pendingTasks[index]),
                    );
                  },
                );
              },
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(height: 100),
            ),
            
            if (userTasksAsync.value != null &&
                userTasksAsync.value!.where((task) => task.status == TaskStatus.pending).length > 3)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to Tasks tab
                    // TODO: Implement navigation to Tasks tab with filter
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View All Pending'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            
            // Recent completed tasks section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.task_alt,
                    color: AppTheme.completedStatusColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Completed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            
            userTasksAsync.when(
              data: (tasks) {
                final completedTasks = tasks
                    .where((task) => task.status == TaskStatus.completed)
                    .toList();
                
                if (completedTasks.isEmpty) {
                  return _EmptyTasksPlaceholder(
                    message: 'No completed tasks yet',
                    icon: Icons.emoji_events_outlined,
                    description: 'Complete your pending tasks to see them here',
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: completedTasks.length > 2 ? 2 : completedTasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TaskCard(task: completedTasks[index]),
                    );
                  },
                );
              },
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(height: 100),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasksPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? description;

  const _EmptyTasksPlaceholder({
    required this.message,
    required this.icon,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondaryColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  final String name;

  const _WelcomeSection({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            Color(0xFF2980B9), // Darker blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Welcome back,',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.formatDate(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Good ${_getTimeOfDay()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }
}

class _TaskStatistics extends StatelessWidget {
  final List<Task> tasks;

  const _TaskStatistics({
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = tasks.where((task) => task.status == TaskStatus.pending).length;
    final acceptedCount = tasks.where((task) => task.status == TaskStatus.accepted).length;
    final completedCount = tasks.where((task) => task.status == TaskStatus.completed).length;
    final totalCount = tasks.length;
    
    // Calculate overdue tasks
    final overdueTasks = tasks.where((task) => task.isOverdue).length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: AppTheme.secondaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Task Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                context,
                count: totalCount,
                label: 'Total',
                icon: Icons.assignment,
                color: AppTheme.primaryColor,
                iconBackgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                count: overdueTasks,
                label: 'Overdue',
                icon: Icons.warning_amber,
                color: AppTheme.errorColor,
                iconBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                context,
                count: pendingCount,
                label: 'Pending',
                icon: Icons.pending_actions,
                color: AppTheme.pendingStatusColor,
                iconBackgroundColor: AppTheme.pendingStatusColor.withOpacity(0.1),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                count: completedCount,
                label: 'Completed',
                icon: Icons.task_alt,
                color: AppTheme.completedStatusColor,
                iconBackgroundColor: AppTheme.completedStatusColor.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar showing overall completion
          if (totalCount > 0) ...[
            Row(
              children: [
                Text(
                  'Completion Rate:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${((completedCount / totalCount) * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? completedCount / totalCount : 0,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.completedStatusColor,
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    required Color iconBackgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 