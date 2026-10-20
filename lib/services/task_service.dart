import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  // ── Real-time stream (all tasks) ───────────────────────────────────────────
  Stream<List<TaskModel>> tasksStream(String uid) =>
      _tasksRef(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(TaskModel.fromDoc).toList());

  // ── Real-time stream (completed tasks only, ordered by completedAt) ────────
  Stream<List<TaskModel>> completedTasksStream(String uid) =>
      _tasksRef(uid)
          .where('isDone', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(TaskModel.fromDoc).toList());

  // ── One-shot fetch (completed tasks) ──────────────────────────────────────
  Future<List<TaskModel>> getCompletedTasks(String uid) async {
    final snap = await _tasksRef(uid)
        .where('isDone', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .get();
    return snap.docs.map(TaskModel.fromDoc).toList();
  }

  // ── Stats: tasks completed in the last N days, grouped by day ─────────────
  /// Returns a map of { dateOnly → count } for tasks completed within
  /// [days] days back from today.
  Future<Map<DateTime, int>> completedTasksByDay(
      String uid, {int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snap = await _tasksRef(uid)
        .where('isDone', isEqualTo: true)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();

    final Map<DateTime, int> result = {};
    for (final doc in snap.docs) {
      final task = TaskModel.fromDoc(doc);
      if (task.completedAt == null) continue;
      final day = DateTime(
        task.completedAt!.year,
        task.completedAt!.month,
        task.completedAt!.day,
      );
      result[day] = (result[day] ?? 0) + 1;
    }
    return result;
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  Future<void> addTask({
    required String uid,
    required String title,
    String? description,
    String? subject,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) =>
      _tasksRef(uid).add(TaskModel(
        id: '',
        uid: uid,
        title: title.trim(),
        description:
            description?.trim().isEmpty ?? true ? null : description?.trim(),
        subject: subject,
        priority: priority,
        isDone: false,
        createdAt: DateTime.now(),
        dueDate: dueDate,
      ).toMap());

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<void> updateTask(String uid, TaskModel task) =>
      _tasksRef(uid).doc(task.id).update(task.toMap());

  // ── Toggle done — sets/clears completedAt accordingly ─────────────────────
  Future<void> toggleDone(String uid, TaskModel task) {
    final nowDone = !task.isDone;
    return _tasksRef(uid).doc(task.id).update({
      'isDone': nowDone,
      'completedAt': nowDone
          ? Timestamp.fromDate(DateTime.now())
          : null, // clear when un-completing
    });
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deleteTask(String uid, String taskId) =>
      _tasksRef(uid).doc(taskId).delete();
}
