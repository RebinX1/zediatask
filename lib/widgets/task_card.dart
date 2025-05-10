import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/screens/task/task_detail_screen.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/utils/date_formatter.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final bool showActions;

  const TaskCard({
    super.key,
    required this.task,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Add a special indicator for available tasks that have no assignee
    final bool isAvailableTask = task.isPending && task.assignedTo.isEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(taskId: task.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Task status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.getStatusColor(task.status.toString().split('.').last),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Task status
                  Text(
                    _getStatusText(task.status),
                    style: TextStyle(
                      color: AppTheme.getStatusColor(task.status.toString().split('.').last),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  // Group task indicator
                  if (task.isGroupTask || isAvailableTask) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAvailableTask ? Icons.person_add : Icons.group,
                            color: Colors.purple,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAvailableTask ? 'Available' : 'Group',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Points indicator (if available)
                  if (task.pointsAwarded != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.pointsAwarded} pts',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Priority indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getPriorityColor(task.priority.toString().split('.').last).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getPriorityText(task.priority),
                      style: TextStyle(
                        color: AppTheme.getPriorityColor(task.priority.toString().split('.').last),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Task title
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              
              const SizedBox(height: 8),
              
              // Task description (truncated)
              Text(
                _truncateDescription(task.description),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Time info section
              Row(
                children: [
                  // Due date
                  if (task.dueDate != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: task.isOverdue
                                ? AppTheme.errorColor
                                : AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormatter.formatDeadline(task.dueDate),
                              style: TextStyle(
                                color: task.isOverdue
                                    ? AppTheme.errorColor
                                    : AppTheme.textSecondaryColor,
                                fontWeight: task.isOverdue ? FontWeight.w500 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Time remaining countdown
                  if (task.dueDate != null && !task.isCompleted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.isOverdue 
                            ? AppTheme.errorColor.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        task.timeRemainingFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: task.isOverdue ? AppTheme.errorColor : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Last comment (if available)
              if (task.lastCommentContent != null && task.lastCommentDate != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.comment,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last comment (${DateFormatter.formatTimeAgo(task.lastCommentDate!)}):',
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _truncateDescription(task.lastCommentContent!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              
              // Task actions
              if (showActions) ...[
                const SizedBox(height: 16),
                _buildActionButtons(context, ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    // Get user role to decide what actions to show
    final userRoleAsync = ref.watch(userRoleProvider);
    final userId = ref.read(supabaseServiceProvider).client.auth.currentUser?.id;
    final isCurrentUserTask = userId != null && task.assignedTo == userId;
    final isUnassignedTask = task.assignedTo.isEmpty;
    
    return userRoleAsync.when(
      data: (userRole) {
        final isManagerOrAdmin = userRole == UserRole.manager || userRole == UserRole.admin;
        
        // If task is pending and unassigned, show 'Claim' button
        if (task.isPending && (isUnassignedTask || task.isGroupTask)) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _claimTask(context, ref),
                icon: const Icon(Icons.person_add),
                label: const Text('Claim'),
              ),
            ],
          );
        }
        
        // If task is pending and assigned to current user, show 'Accept' button
        if (task.isPending && isCurrentUserTask) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _updateTaskStatus(context, ref, TaskStatus.accepted),
                child: const Text('Accept'),
              ),
            ],
          );
        }
        
        // If task is accepted and assigned to current user, show 'Complete' button
        if (task.isAccepted && isCurrentUserTask) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _updateTaskStatus(context, ref, TaskStatus.completed),
                child: const Text('Complete'),
              ),
            ],
          );
        }
        
        // If manager/admin, show appropriate action buttons even for tasks not assigned to them
        if (isManagerOrAdmin) {
          if (task.isPending) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _updateTaskStatus(context, ref, TaskStatus.accepted),
                  child: const Text('Accept'),
                ),
              ],
            );
          } else if (task.isAccepted) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _updateTaskStatus(context, ref, TaskStatus.completed),
                  child: const Text('Complete'),
                ),
              ],
            );
          }
        }
        
        return const SizedBox.shrink();
      },
      loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _updateTaskStatus(BuildContext context, WidgetRef ref, TaskStatus newStatus) {
    final supabaseService = ref.read(supabaseServiceProvider);
    
    // Show a more subtle indicator instead of a full-screen snackbar
    final loadingIndicator = Center(
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.all(2),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
    
    // Use an overlay instead of a Snackbar to avoid full screen rebuilds
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 16,
        right: 16,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                loadingIndicator,
                const SizedBox(width: 8),
                const Text(
                  'Updating...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Show the overlay
    Overlay.of(context).insert(overlay);
    
    supabaseService.updateTaskStatus(
      taskId: task.id,
      status: newStatus,
    ).then((updatedTask) {
      // First remove the overlay
      overlay.remove();
      
      // Show a success message
      final successOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    newStatus == TaskStatus.accepted
                        ? 'Task accepted'
                        : 'Task completed',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Show success overlay
      Overlay.of(context).insert(successOverlay);
      
      // Auto-remove after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        successOverlay.remove();
      });
      
      // Only refresh this specific task and notify about the update 
      // without refreshing the entire list
      ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
      
    }).catchError((error) {
      // First remove the overlay
      overlay.remove();
      
      // Show error message
      final errorOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Show error overlay
      Overlay.of(context).insert(errorOverlay);
      
      // Auto-remove after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        errorOverlay.remove();
      });
    });
  }

  void _claimTask(BuildContext context, WidgetRef ref) {
    final supabaseService = ref.read(supabaseServiceProvider);
    
    // Show a more subtle indicator instead of a full-screen snackbar
    final loadingIndicator = Center(
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.all(2),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
    
    // Use an overlay instead of a Snackbar to avoid full screen rebuilds
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 16,
        right: 16,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                loadingIndicator,
                const SizedBox(width: 8),
                const Text(
                  'Claiming task...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Show the overlay
    Overlay.of(context).insert(overlay);
    
    supabaseService.claimGroupTask(
      taskId: task.id,
    ).then((updatedTask) {
      // First remove the overlay
      overlay.remove();
      
      // Show a success message
      final successOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Task claimed successfully!',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Show success overlay
      Overlay.of(context).insert(successOverlay);
      
      // Auto-remove after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        successOverlay.remove();
      });
      
      // Only refresh this specific task and notify about the update 
      // without refreshing the entire list
      ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
      
    }).catchError((error) {
      // First remove the overlay
      overlay.remove();
      
      // Show error message
      final errorOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Show error overlay
      Overlay.of(context).insert(errorOverlay);
      
      // Auto-remove after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        errorOverlay.remove();
      });
    });
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.accepted:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  String _truncateDescription(String description) {
    if (description.length <= 100) {
      return description;
    }
    return '${description.substring(0, 100)}...';
  }
} 