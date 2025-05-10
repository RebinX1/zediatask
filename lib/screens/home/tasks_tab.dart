import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/widgets/task_card.dart';
import 'dart:async';

// A provider to track the current filter
final taskFilterProvider = StateProvider<TaskStatus?>((ref) => null);

class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key});

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> with AutomaticKeepAliveClientMixin {
  // Keep this tab alive when switching between tabs to maintain its state
  @override
  bool get wantKeepAlive => true;
  
  // Add a key for the list to force rebuild when real-time tasks change
  final _listKey = GlobalKey<AnimatedListState>();
  
  // Create a scroll controller to allow scrolling to top when new tasks arrive
  final ScrollController _scrollController = ScrollController();
  
  // Track when the list was last rebuilt
  DateTime _lastRebuildTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    
    // Set up real-time subscription on startup
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _ensureRealtimeSubscription();
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _ensureRealtimeSubscription() {
    // Make sure real-time provider is initialized
    final supabaseService = ref.read(supabaseServiceProvider);
    if (!supabaseService.hasActiveTasksSubscription) {
      // Initialize the real-time subscription if not active
      ref.read(realtimeTasksProvider.notifier).refreshTasks();
      print('Ensuring real-time subscription is active');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final selectedFilter = ref.watch(taskFilterProvider);
    final selectedDateFilter = ref.watch(dateFilterProvider);
    
    // Get current user role
    final loggedInUser = ref.watch(loggedInUserProvider);
    final isAdmin = loggedInUser?.role == UserRole.admin;
    
    // Listen to task stream for real-time updates
    ref.listen<AsyncValue<void>>(taskStreamProvider, (previous, next) {
      setState(() {
        _lastRebuildTime = DateTime.now();
        print('UI refresh triggered by task stream at $_lastRebuildTime');
      });
    });
    
    // Directly observe task update notifier to refresh on changes
    ref.listen(taskUpdateNotifierProvider, (previous, next) {
      if (previous != next) {
        // Trigger refresh when task update notifier changes
        setState(() {
          _lastRebuildTime = DateTime.now();
        });
      }
    });
    
    // Observe real-time tasks to rebuild when tasks change
    final realtimeTasks = ref.watch(realtimeFilteredTasksProvider(selectedFilter));
    
    // For admin users, use a filtered version of tasks that doesn't depend on taskUpdateNotifierProvider
    final filteredTasksAsync = isAdmin 
        ? ref.watch(adminFilteredTasksProvider(selectedFilter))
        : ref.watch(filteredTasksProvider(selectedFilter));
        
    final userDetailsAsync = ref.watch(userDetailsProvider);
    
    // Debug the current user details
    userDetailsAsync.whenData((userDetails) {
      if (userDetails != null) {
        print('Current user - ID: ${userDetails['id']}, Name: ${userDetails['name']}, Role: ${userDetails['role']}');
      }
    });
    
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
        
        // Status filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  ref,
                  label: 'All',
                  value: null,
                  selectedFilter: selectedFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Pending',
                  value: TaskStatus.pending,
                  selectedFilter: selectedFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'In Progress',
                  value: TaskStatus.accepted,
                  selectedFilter: selectedFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Completed',
                  value: TaskStatus.completed,
                  selectedFilter: selectedFilter,
                ),
              ],
            ),
          ),
        ),
        
        // Task list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh both real-time and regular providers
              ref.refresh(userTasksProvider);
              ref.read(realtimeTasksProvider.notifier).refreshTasks();
              // Trigger a UI update via the task update notifier
              ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
              // Update the rebuild time
              setState(() {
                _lastRebuildTime = DateTime.now();
              });
            },
            child: realtimeTasks.isNotEmpty
                ? _buildRealtimeTaskList(realtimeTasks, selectedFilter)
                : filteredTasksAsync.when(
                    data: (filteredTasks) {
                      if (filteredTasks.isEmpty) {
                        return _buildEmptyState(context, selectedFilter);
                      }
                      return _buildTaskList(filteredTasks, selectedFilter);
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

  Widget _buildRealtimeTaskList(List<Task> tasks, TaskStatus? selectedFilter) {
    if (tasks.isEmpty) {
      return _buildEmptyState(context, selectedFilter);
    }
    
    // Use a key based on the task count and last rebuild time to force rebuilds
    final keyString = "${tasks.length}-${_lastRebuildTime.millisecondsSinceEpoch}";
    
    // Check if there are any newly added tasks (added in the last 10 seconds)
    bool hasNewTasks = tasks.any((task) => 
      DateTime.now().difference(task.createdAt).inSeconds < 10);
    
    // If there are new tasks, scroll to top after render
    if (hasNewTasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        controller: _scrollController,
        key: Key(keyString),
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          // Check if this is a recently added task (in the last 10 seconds)
          final isNewTask = DateTime.now().difference(tasks[index].createdAt).inSeconds < 10;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: isNewTask
                ? _buildHighlightedTaskCard(tasks[index])
                : TaskCard(task: tasks[index]),
          );
        },
      ),
    );
  }
  
  Widget _buildHighlightedTaskCard(Task task) {
    // Highlight new tasks with an animation
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3 * (1 - value)),
                    blurRadius: 10,
                    spreadRadius: 2 * (1 - value),
                  ),
                ],
              ),
              child: child,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: 1.0 - value,
                duration: const Duration(seconds: 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: TaskCard(task: task),
    );
  }
  
  Widget _buildTaskList(List<Task> tasks, TaskStatus? selectedFilter) {
    if (tasks.isEmpty) {
      return _buildEmptyState(context, selectedFilter);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TaskCard(
            task: tasks[index],
          ),
        );
      },
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

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required TaskStatus? value,
    required TaskStatus? selectedFilter,
  }) {
    final isSelected = value == selectedFilter;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (isSelected) {
        ref.read(taskFilterProvider.notifier).state = isSelected ? value : null;
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

  Widget _buildEmptyState(BuildContext context, TaskStatus? filter) {
    String message;
    IconData icon;
    
    if (filter == null) {
      message = 'No tasks available';
      icon = Icons.assignment_outlined;
    } else if (filter == TaskStatus.pending) {
      message = 'No pending tasks';
      icon = Icons.pending_actions_outlined;
    } else if (filter == TaskStatus.accepted) {
      message = 'No tasks in progress';
      icon = Icons.hourglass_empty;
    } else {
      message = 'No completed tasks';
      icon = Icons.task_alt;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.textLightColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: 8),
          if (filter != null)
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  ref.read(taskFilterProvider.notifier).state = null;
                },
                child: const Text('Show All Tasks'),
              ),
            ),
        ],
      ),
    );
  }
} 