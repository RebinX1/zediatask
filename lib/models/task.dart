import 'package:flutter/foundation.dart';

enum TaskStatus {
  pending,
  accepted,
  completed,
}

enum TaskPriority {
  low,
  medium,
  high,
}

class Task {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final TaskStatus status;
  final TaskPriority priority;
  final List<String> tags;
  final int? pointsAwarded;
  final String? lastCommentContent;
  final DateTime? lastCommentDate;
  final bool isGroupTask;
  final List<String> originalAssignedTo;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    this.dueDate,
    this.acceptedAt,
    this.completedAt,
    required this.status,
    required this.priority,
    required this.tags,
    this.pointsAwarded,
    this.lastCommentContent,
    this.lastCommentDate,
    this.isGroupTask = false,
    this.originalAssignedTo = const [],
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? acceptedAt,
    DateTime? completedAt,
    TaskStatus? status,
    TaskPriority? priority,
    List<String>? tags,
    int? pointsAwarded,
    String? lastCommentContent,
    DateTime? lastCommentDate,
    bool? isGroupTask,
    List<String>? originalAssignedTo,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      lastCommentContent: lastCommentContent ?? this.lastCommentContent,
      lastCommentDate: lastCommentDate ?? this.lastCommentDate,
      isGroupTask: isGroupTask ?? this.isGroupTask,
      originalAssignedTo: originalAssignedTo ?? this.originalAssignedTo,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      assignedTo: json['assigned_to'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      status: _parseTaskStatus(json['status']),
      priority: _parseTaskPriority(json['priority']),
      tags: List<String>.from(json['tags'] ?? []),
      pointsAwarded: json['points_awarded'],
      lastCommentContent: json['last_comment_content'],
      lastCommentDate: json['last_comment_date'] != null ? DateTime.parse(json['last_comment_date']) : null,
      isGroupTask: json['is_group_task'] ?? false,
      originalAssignedTo: json['original_assigned_to'] != null 
          ? List<String>.from(json['original_assigned_to']) 
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'tags': tags,
      'points_awarded': pointsAwarded,
      'last_comment_content': lastCommentContent,
      'last_comment_date': lastCommentDate?.toIso8601String(),
      'is_group_task': isGroupTask,
      'original_assigned_to': originalAssignedTo,
    };
  }

  static TaskStatus _parseTaskStatus(String status) {
    switch (status) {
      case 'pending':
        return TaskStatus.pending;
      case 'accepted':
        return TaskStatus.accepted;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  static TaskPriority _parseTaskPriority(String priority) {
    switch (priority) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  bool get isPending => status == TaskStatus.pending;
  bool get isAccepted => status == TaskStatus.accepted;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!) && !isCompleted;
  
  Duration? get timeToAccept => acceptedAt != null ? acceptedAt!.difference(createdAt) : null;
  Duration? get timeToComplete => completedAt != null && acceptedAt != null ? completedAt!.difference(acceptedAt!) : null;
  
  // Calculate time remaining for the task
  Duration? get timeRemaining {
    if (dueDate == null || isCompleted) return null;
    final now = DateTime.now();
    if (now.isAfter(dueDate!)) return Duration.zero; // Overdue
    return dueDate!.difference(now);
  }
  
  // Format time remaining as a readable string
  String get timeRemainingFormatted {
    final remaining = timeRemaining;
    if (remaining == null) return 'No deadline';
    if (remaining.inSeconds <= 0) return 'Overdue';
    
    if (remaining.inDays > 1) {
      return '${remaining.inDays} days left';
    } else if (remaining.inDays == 1) {
      return '1 day left';
    } else if (remaining.inHours > 1) {
      return '${remaining.inHours} hours left';
    } else if (remaining.inHours == 1) {
      return '1 hour left';
    } else if (remaining.inMinutes > 1) {
      return '${remaining.inMinutes} minutes left';
    } else {
      return 'Less than a minute left';
    }
  }
} 