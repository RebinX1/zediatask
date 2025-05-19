import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/screens/task/add_attachment_screen.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/utils/date_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:cached_network_image/cached_network_image.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  bool _visibleToEmployee = true;
  bool _isUpdatingStatus = false;
  Task? _currentTask;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Set the selected task ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTaskIdProvider.notifier).state = widget.taskId;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(selectedTaskProvider);
    final commentsAsync = ref.watch(taskCommentsProvider(widget.taskId));
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(widget.taskId));
    final userRoleAsync = ref.watch(userRoleProvider);
    
    // Use local task if available and the provider is not refreshed yet
    final useLocalTask = _currentTask != null && taskAsync.valueOrNull?.id == widget.taskId;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Comments'),
            Tab(text: 'Photos'),
          ],
        ),
      ),
      body: useLocalTask
          ? TabBarView(
              controller: _tabController,
              children: [
                // Details tab with local task
                _buildDetailsTab(context, _currentTask!, userRoleAsync),
                
                // Comments tab
                _buildCommentsTab(context, commentsAsync, userRoleAsync),
                
                // Photos tab
                _buildAttachmentsTab(context, attachmentsAsync),
              ],
            )
          : taskAsync.when(
              data: (task) {
                if (task == null) {
                  return const Center(
                    child: Text('Task not found'),
                  );
                }
                
                // Store the task locally for future use
                if (_currentTask == null) {
                  _currentTask = task;
                }
                
                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Details tab
                    _buildDetailsTab(context, task, userRoleAsync),
                    
                    // Comments tab
                    _buildCommentsTab(context, commentsAsync, userRoleAsync),
                    
                    // Photos tab
                    _buildAttachmentsTab(context, attachmentsAsync),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
      bottomNavigationBar: useLocalTask 
          ? _buildBottomActionBar(context, _currentTask!)
          : taskAsync.when(
              data: (task) {
                if (task == null) {
                  return null;
                }
                
                return _buildBottomActionBar(context, task);
              },
              loading: () => null,
              error: (_, __) => null,
            ),
    );
  }

  Widget _buildDetailsTab(
    BuildContext context,
    Task task,
    AsyncValue<UserRole?> userRoleAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and priority indicators
          Row(
            children: [
              _buildStatusBadge(task.status),
              const Spacer(),
              // Display points if awarded
              if (task.pointsAwarded != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${task.pointsAwarded} pts',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildPriorityBadge(task.priority),
            ],
          ),
          const SizedBox(height: 16),
          
          // Task title
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // Date information
          _buildDateInfo(task),
          
          // Time remaining countdown
          if (task.dueDate != null && !task.isCompleted) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: task.isOverdue 
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    task.isOverdue 
                        ? Icons.warning_amber_rounded 
                        : Icons.hourglass_bottom,
                    color: task.isOverdue ? AppTheme.errorColor : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.isOverdue ? 'Overdue Task' : 'Time Remaining',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: task.isOverdue ? AppTheme.errorColor : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.timeRemainingFormatted,
                          style: TextStyle(
                            color: task.isOverdue ? AppTheme.errorColor : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          
          // Divider
          const Divider(),
          const SizedBox(height: 16),
          
          // Task information
          _buildTaskInfoSection(task),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Description header
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          
          // Task description
          Text(
            task.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          
          // Tags
          if (task.tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: task.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: AppTheme.primaryColor,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Points awarded section (if completed)
          if (task.isCompleted && task.pointsAwarded != null) ...[
            Text(
              'Points Awarded',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${task.pointsAwarded} points',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Points earned for completing this task',
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Last comment section (if any)
          if (task.lastCommentContent != null && task.lastCommentDate != null) ...[
            Text(
              'Last Comment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.comment,
                        color: AppTheme.textSecondaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.formatTimeAgo(task.lastCommentDate!),
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.lastCommentContent!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsTab(
    BuildContext context,
    AsyncValue<List<Comment>> commentsAsync,
    AsyncValue<UserRole?> userRoleAsync,
  ) {
    return Column(
      children: [
        // Comments list
        Expanded(
          child: commentsAsync.when(
            data: (comments) {
              if (comments.isEmpty) {
                return const Center(
                  child: Text('No comments yet'),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  
                  // Check if comment should be visible to employees
                  final bool isVisible = userRoleAsync.maybeWhen(
                    data: (role) {
                      if (role == UserRole.employee) {
                        return comment.visibleToEmployee;
                      }
                      return true;
                    },
                    orElse: () => true,
                  );
                  
                  if (!isVisible) {
                    return const SizedBox.shrink();
                  }
                  
                  return _buildCommentItem(context, comment);
                },
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
        
        // Add comment form
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              
              // Visibility toggle for managers/admins
              userRoleAsync.maybeWhen(
                data: (role) {
                  if (role == UserRole.manager || role == UserRole.admin) {
                    return Row(
                      children: [
                        Checkbox(
                          value: _visibleToEmployee,
                          onChanged: (value) {
                            setState(() {
                              _visibleToEmployee = value ?? true;
                            });
                          },
                        ),
                        const Text('Visible to employee'),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Add comment
                            if (_commentController.text.trim().isNotEmpty) {
                              ref.read(supabaseServiceProvider).addComment(
                                taskId: widget.taskId,
                                content: _commentController.text.trim(),
                                visibleToEmployee: _visibleToEmployee,
                              );
                              _commentController.clear();
                              
                              // Refresh comments
                              ref.refresh(taskCommentsProvider(widget.taskId));
                            }
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('Post'),
                        ),
                      ],
                    );
                  }
                  return Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Add comment
                        if (_commentController.text.trim().isNotEmpty) {
                          ref.read(supabaseServiceProvider).addComment(
                            taskId: widget.taskId,
                            content: _commentController.text.trim(),
                            visibleToEmployee: true, // Employees can only post visible comments
                          );
                          _commentController.clear();
                          
                          // Refresh comments
                          ref.refresh(taskCommentsProvider(widget.taskId));
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Post'),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsTab(
    BuildContext context,
    AsyncValue<List<Attachment>> attachmentsAsync,
  ) {
    return Column(
      children: [
        // Add attachment button (Only visible for managers and admins)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer(
            builder: (context, ref, child) {
              final userRoleAsync = ref.watch(userRoleProvider);
              
              return userRoleAsync.maybeWhen(
                data: (role) {
                  if (role == UserRole.manager || role == UserRole.admin) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AddAttachmentScreen(taskId: widget.taskId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photo'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
        ),
        
        // Photos grid
        Expanded(
          child: attachmentsAsync.when(
            data: (attachments) {
              if (attachments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: AppTheme.textLightColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No photos yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                    ],
                  ),
                );
              }
              
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    // Filter to only show images if needed
                    final isImage = _isImageAttachment(attachment.fileName);
                    
                    return GestureDetector(
                      onTap: () => _viewPhoto(context, attachment),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            CachedNetworkImage(
                              imageUrl: attachment.fileUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade400,
                                  size: 40,
                                ),
                              ),
                            ),
                            
                            // Gradient overlay at bottom for text
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, 
                                  horizontal: 12.0,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  attachment.fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
      ],
    );
  }

  bool _isImageAttachment(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(ext);
  }

  // Open a photo in full screen view
  void _viewPhoto(BuildContext context, Attachment attachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(attachment: attachment),
      ),
    );
  }

  Widget? _buildBottomActionBar(BuildContext context, Task task) {
    // Don't show action bar for completed tasks
    if (task.isCompleted) {
      return null;
    }

    // Get current user role
    final userRoleAsync = ref.watch(userRoleProvider);
    
    return userRoleAsync.when(
      data: (userRole) {
        // Show different action bar based on task status and user role
        return BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _isUpdatingStatus
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                // For unassigned tasks
                                if ((task.isGroupTask || task.assignedTo.isEmpty) && task.isPending) {
                                  _claimGroupTask(context);
                                } 
                                // For tasks assigned to others (manager can reassign)
                                else if (userRole == UserRole.manager || userRole == UserRole.admin) {
                                  _updateTaskStatus(
                                    context,
                                    task.status == TaskStatus.pending
                                        ? TaskStatus.accepted
                                        : TaskStatus.completed,
                                  );
                                }
                                // For tasks assigned to this user
                                else if (task.assignedTo == ref.read(supabaseServiceProvider).client.auth.currentUser?.id) {
                                  _updateTaskStatus(
                                    context,
                                    task.status == TaskStatus.pending
                                        ? TaskStatus.accepted
                                        : TaskStatus.completed,
                                  );
                                }
                              },
                              child: Text(
                                _getActionButtonText(task),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                
                // Add a test controls button in debug mode
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _showTestControls(context, task),
                    child: const Text('Test Controls'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const BottomAppBar(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const BottomAppBar(
        child: Center(child: Text('Error loading user role')),
      ),
    );
  }
  
  String _getActionButtonText(Task task) {
    // Handle the case where the task is pending and either:
    // 1. It's marked as a group task, or
    // 2. It has no assignee (which suggests it might be a group task)
    if ((task.isGroupTask || task.assignedTo.isEmpty) && task.isPending) {
      return 'Claim Task';
    } else {
      return task.status == TaskStatus.pending
          ? 'Accept Task'
          : 'Complete Task';
    }
  }
  
  // Show a dialog with test controls
  void _showTestControls(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Add 5 points'),
              leading: const Icon(Icons.star),
              onTap: () async {
                final supabaseService = ref.read(supabaseServiceProvider);
                await supabaseService.addPointsToTask(
                  taskId: task.id, 
                  points: 5,
                );
                
                // Refresh the task
                ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
                
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Add 10 points'),
              leading: const Icon(Icons.stars),
              onTap: () async {
                final supabaseService = ref.read(supabaseServiceProvider);
                await supabaseService.addPointsToTask(
                  taskId: task.id, 
                  points: 10,
                );
                
                // Refresh the task
                ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
                
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Add test comment'),
              leading: const Icon(Icons.comment),
              onTap: () async {
                final supabaseService = ref.read(supabaseServiceProvider);
                await supabaseService.addTestComment(
                  taskId: task.id,
                );
                
                // Refresh the task
                ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
                
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _claimGroupTask(BuildContext context) {
    final supabaseService = ref.read(supabaseServiceProvider);
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    supabaseService.claimGroupTask(
      taskId: widget.taskId,
    ).then((updatedTask) {
      // Store the updated task locally
      setState(() {
        _currentTask = updatedTask;
        _isUpdatingStatus = false;
      });
      
      // Notify about the update
      ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task claimed successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }).catchError((error) {
      setState(() {
        _isUpdatingStatus = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    });
  }

  void _updateTaskStatus(BuildContext context, TaskStatus newStatus) {
    final supabaseService = ref.read(supabaseServiceProvider);
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    supabaseService.updateTaskStatus(
      taskId: widget.taskId, 
      status: newStatus,
    ).then((updatedTask) {
      // Store the updated task locally
      setState(() {
        _currentTask = updatedTask;
        _isUpdatingStatus = false;
      });
      
      // Notify about the update
      ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == TaskStatus.accepted
                ? 'Task accepted'
                : 'Task completed',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }).catchError((error) {
      setState(() {
        _isUpdatingStatus = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    });
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case TaskStatus.pending:
        color = AppTheme.pendingStatusColor;
        text = 'Pending';
        break;
      case TaskStatus.accepted:
        color = AppTheme.acceptedStatusColor;
        text = 'In Progress';
        break;
      case TaskStatus.completed:
        color = AppTheme.completedStatusColor;
        text = 'Completed';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == TaskStatus.pending
                ? Icons.pending
                : status == TaskStatus.accepted
                    ? Icons.sync
                    : Icons.check_circle,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    String text;
    
    switch (priority) {
      case TaskPriority.low:
        color = AppTheme.lowPriorityColor;
        text = 'Low Priority';
        break;
      case TaskPriority.medium:
        color = AppTheme.mediumPriorityColor;
        text = 'Medium Priority';
        break;
      case TaskPriority.high:
        color = AppTheme.highPriorityColor;
        text = 'High Priority';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priority == TaskPriority.low
                ? Icons.arrow_downward
                : priority == TaskPriority.medium
                    ? Icons.remove
                    : Icons.arrow_upward,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Created date
        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Created on ${DateFormatter.formatDateTime(task.createdAt)}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Due date (if set)
        if (task.dueDate != null)
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: task.isOverdue
                    ? AppTheme.errorColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormatter.formatDeadlineWithDate(task.dueDate),
                style: TextStyle(
                  color: task.isOverdue
                      ? AppTheme.errorColor
                      : AppTheme.textSecondaryColor,
                  fontWeight: task.isOverdue ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        
        // Accepted date (if accepted)
        if (task.acceptedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.login,
                size: 16,
                color: AppTheme.acceptedStatusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Accepted on ${DateFormatter.formatDateTime(task.acceptedAt!)}',
                style: const TextStyle(
                  color: AppTheme.acceptedStatusColor,
                ),
              ),
            ],
          ),
        ],
        
        // Completed date (if completed)
        if (task.completedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.task_alt,
                size: 16,
                color: AppTheme.completedStatusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Completed on ${DateFormatter.formatDateTime(task.completedAt!)}',
                style: const TextStyle(
                  color: AppTheme.completedStatusColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentItem(BuildContext context, Comment comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User', // This would ideally display the user's name
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormatter.timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (!comment.visibleToEmployee)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Only Managers',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment.content),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoSection(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Task Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        
        // Assignment info
        Row(
          children: [
            const Icon(
              Icons.person,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: task.isGroupTask && task.isPending
                  ? const Text(
                      'Group Task - First to claim',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : FutureBuilder<User?>(
                      future: task.assignedTo.isNotEmpty 
                          ? ref.read(supabaseServiceProvider).getUserById(task.assignedTo)
                          : Future.value(null),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Loading...');
                        }
                        
                        if (task.assignedTo.isEmpty) {
                          return const Text(
                            'Unassigned - First to claim',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                        
                        final assignedToUser = snapshot.data;
                        return Text(
                          assignedToUser != null
                              ? 'Assigned to: ${assignedToUser.name}'
                              : 'Assigned to: Unknown',
                        );
                      },
                    ),
            ),
          ],
        ),
        
        // Group task info (if applicable)
        if (task.isGroupTask) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.group,
                size: 16,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: task.isPending
                    ? const Text(
                        'This task is available to multiple employees.\nFirst to claim it gets to complete it.',
                        style: TextStyle(color: Colors.purple),
                      )
                    : FutureBuilder<User?>(
                        future: task.assignedTo.isNotEmpty 
                            ? ref.read(supabaseServiceProvider).getUserById(task.assignedTo)
                            : Future.value(null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Loading claimed user info...');
                          }
                          
                          if (task.assignedTo.isEmpty) {
                            return const Text(
                              'Task not yet claimed',
                              style: TextStyle(color: Colors.purple),
                            );
                          }
                          
                          final claimedByUser = snapshot.data;
                          return Text(
                            'Group task claimed by: ${claimedByUser?.name ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.purple),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
        
        // Creator info
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.person_add,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FutureBuilder<User?>(
                future: task.createdBy.isNotEmpty 
                    ? ref.read(supabaseServiceProvider).getUserById(task.createdBy)
                    : Future.value(null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading...');
                  }
                  
                  if (task.createdBy.isEmpty) {
                    return const Text('Created by: Unknown');
                  }
                  
                  final createdByUser = snapshot.data;
                  return Text(
                    createdByUser != null
                        ? 'Created by: ${createdByUser.name}'
                        : 'Created by: Unknown',
                  );
                },
              ),
            ),
          ],
        ),
        
        // Creation date
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.date_range,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Text('Created on ${DateFormatter.formatDateTime(task.createdAt)}'),
          ],
        ),
        
        // Due date (if set)
        if (task.dueDate != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.event,
                size: 16,
                color: task.isOverdue
                    ? AppTheme.errorColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Due on ${DateFormatter.formatDateTime(task.dueDate!)}',
                style: TextStyle(
                  color: task.isOverdue ? AppTheme.errorColor : null,
                  fontWeight: task.isOverdue ? FontWeight.w500 : null,
                ),
              ),
            ],
          ),
        ],
        
        // Acceptance date (if accepted)
        if (task.acceptedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.login,
                size: 16,
                color: AppTheme.acceptedStatusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Accepted on ${DateFormatter.formatDateTime(task.acceptedAt!)}',
                style: const TextStyle(
                  color: AppTheme.acceptedStatusColor,
                ),
              ),
            ],
          ),
        ],
        
        // Completed date (if completed)
        if (task.completedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.task_alt,
                size: 16,
                color: AppTheme.completedStatusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Completed on ${DateFormatter.formatDateTime(task.completedAt!)}',
                style: const TextStyle(
                  color: AppTheme.completedStatusColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class PhotoViewScreen extends StatelessWidget {
  final Attachment attachment;

  const PhotoViewScreen({
    super.key, 
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          attachment.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePhoto(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            minScale: 0.5,
            child: CachedNetworkImage(
              imageUrl: attachment.fileUrl,
              fit: BoxFit.contain, 
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              errorWidget: (context, url, error) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 50, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load image: $error',
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sharePhoto() {
    // This is where you'd implement sharing functionality
    // For now, just print the URL
    print('Sharing photo: ${attachment.fileUrl}');
  }
} 