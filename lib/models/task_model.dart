import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

class TaskModel {
  final String id;
  final String uid;
  final String title;
  final String? description;
  final String? subject;       // null = no subject
  final TaskPriority priority;
  final bool isDone;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt; // set when isDone is toggled true

  const TaskModel({
    required this.id,
    required this.uid,
    required this.title,
    this.description,
    this.subject,
    required this.priority,
    required this.isDone,
    required this.createdAt,
    this.dueDate,
    this.completedAt,
  });

  // ── Firestore serialisation ────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'description': description,
        'subject': subject,
        'priority': priority.name,          // 'low' | 'medium' | 'high'
        'isDone': isDone,
        'createdAt': Timestamp.fromDate(createdAt),
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  factory TaskModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      uid: d['uid'] as String,
      title: d['title'] as String,
      description: d['description'] as String?,
      subject: d['subject'] as String?,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == (d['priority'] as String? ?? 'medium'),
        orElse: () => TaskPriority.medium,
      ),
      isDone: (d['isDone'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      dueDate: d['dueDate'] != null
          ? (d['dueDate'] as Timestamp).toDate()
          : null,
      completedAt: d['completedAt'] != null
          ? (d['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ── Convenience copy ───────────────────────────────────────────────────────
  TaskModel copyWith({
    String? title,
    String? description,
    String? subject,
    TaskPriority? priority,
    bool? isDone,
    DateTime? dueDate,
    DateTime? completedAt,
    bool clearSubject = false,
    bool clearDueDate = false,
    bool clearDescription = false,
    bool clearCompletedAt = false,
  }) =>
      TaskModel(
        id: id,
        uid: uid,
        title: title ?? this.title,
        description:
            clearDescription ? null : (description ?? this.description),
        subject: clearSubject ? null : (subject ?? this.subject),
        priority: priority ?? this.priority,
        isDone: isDone ?? this.isDone,
        createdAt: createdAt,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  // ── Display helpers ────────────────────────────────────────────────────────
  String get dueDateLabel {
    if (dueDate == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (d.isBefore(today)) return 'Overdue';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dueDate!.day} ${months[dueDate!.month - 1]}';
  }

  bool get isOverdue =>
      dueDate != null &&
      !isDone &&
      dueDate!.isBefore(DateTime.now());

  /// Label for when this task was completed, e.g. "Today", "Yesterday", "3 Jan"
  String get completedAtLabel {
    if (completedAt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(completedAt!.year, completedAt!.month, completedAt!.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${completedAt!.day} ${months[completedAt!.month - 1]}';
  }
}
