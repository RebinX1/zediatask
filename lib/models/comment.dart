import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final String taskId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final bool visibleToEmployee;

  Comment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.visibleToEmployee,
  });

  Comment copyWith({
    String? id,
    String? taskId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    bool? visibleToEmployee,
  }) {
    return Comment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      visibleToEmployee: visibleToEmployee ?? this.visibleToEmployee,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      taskId: json['task_id'],
      authorId: json['author_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      visibleToEmployee: json['visible_to_employee'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'author_id': authorId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'visible_to_employee': visibleToEmployee,
    };
  }
} 