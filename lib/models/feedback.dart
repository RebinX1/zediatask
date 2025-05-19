import 'package:flutter/foundation.dart';

class TaskFeedback {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final DateTime createdAt;

  TaskFeedback({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  TaskFeedback copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? content,
    DateTime? createdAt,
  }) {
    return TaskFeedback(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TaskFeedback.fromJson(Map<String, dynamic> json) {
    return TaskFeedback(
      id: json['id'],
      taskId: json['task_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 