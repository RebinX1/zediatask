import 'package:flutter/foundation.dart';

class Attachment {
  final String id;
  final String taskId;
  final String fileUrl;
  final String fileName;
  final String uploadedBy;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.taskId,
    required this.fileUrl,
    required this.fileName,
    required this.uploadedBy,
    required this.createdAt,
  });

  Attachment copyWith({
    String? id,
    String? taskId,
    String? fileUrl,
    String? fileName,
    String? uploadedBy,
    DateTime? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'],
      taskId: json['task_id'],
      fileUrl: json['file_url'],
      fileName: json['file_name'] ?? 'Unnamed File',
      uploadedBy: json['uploaded_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'file_url': fileUrl,
      'file_name': fileName,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 