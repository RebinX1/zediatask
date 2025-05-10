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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
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

            const SizedBox(height: 24),
            
            // Task statistics
            userTasksAsync.when(
              data: (tasks) => _TaskStatistics(tasks: tasks),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const Center(
                child: Text('Error loading tasks'),
              ),
            ),

            const SizedBox(height: 24),
            
            // Pending tasks section
            Text(
              'Pending Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            userTasksAsync.when(
              data: (tasks) {
                final pendingTasks = tasks
                    .where((task) => task.status == TaskStatus.pending)
                    .toList();
                
                if (pendingTasks.isEmpty) {
                  return const Center(
                    child: Text('No pending tasks'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingTasks.length > 3 ? 3 : pendingTasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TaskCard(task: pendingTasks[index]),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const Center(
                child: Text('Error loading tasks'),
              ),
            ),
            
            if (userTasksAsync.value != null &&
                userTasksAsync.value!.where((task) => task.status == TaskStatus.pending).length > 3)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate to Tasks tab
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View All'),
                ),
              ),

            const SizedBox(height: 24),
            
            // Recent completed tasks section
            Text(
              'Recently Completed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            userTasksAsync.when(
              data: (tasks) {
                final completedTasks = tasks
                    .where((task) => task.status == TaskStatus.completed)
                    .toList();
                
                if (completedTasks.isEmpty) {
                  return const Center(
                    child: Text('No completed tasks'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: completedTasks.length > 2 ? 2 : completedTasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TaskCard(task: completedTasks[index]),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const Center(
                child: Text('Error loading tasks'),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Today is ${DateFormatter.formatDate(DateTime.now())}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
        ],
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatCard(
              title: 'Total',
              value: totalCount.toString(),
              color: AppTheme.primaryColor,
              icon: Icons.assignment,
            ),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Pending',
              value: pendingCount.toString(),
              color: AppTheme.pendingStatusColor,
              icon: Icons.pending_actions,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              title: 'In Progress',
              value: acceptedCount.toString(),
              color: AppTheme.acceptedStatusColor,
              icon: Icons.hourglass_bottom,
            ),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Completed',
              value: completedCount.toString(),
              color: AppTheme.completedStatusColor,
              icon: Icons.task_alt,
            ),
          ],
        ),
        if (overdueTasks > 0) ...[
          const SizedBox(height: 12),
          _OverdueAlert(overdueCount: overdueTasks),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueAlert extends StatelessWidget {
  final int overdueCount;

  const _OverdueAlert({
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have $overdueCount overdue ${overdueCount == 1 ? 'task' : 'tasks'}',
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 