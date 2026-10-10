import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  // ── Real-time stream ───────────────────────────────────────────────────────
  Stream<List<TaskModel>> tasksStream(String uid) =>
      _tasksRef(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(TaskModel.fromDoc).toList());

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
        description: description?.trim().isEmpty ?? true ? null : description?.trim(),
        subject: subject,
        priority: priority,
        isDone: false,
        createdAt: DateTime.now(),
        dueDate: dueDate,
      ).toMap());

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<void> updateTask(String uid, TaskModel task) =>
      _tasksRef(uid).doc(task.id).update(task.toMap());

  // ── Toggle done ────────────────────────────────────────────────────────────
  Future<void> toggleDone(String uid, TaskModel task) =>
      _tasksRef(uid).doc(task.id).update({'isDone': !task.isDone});

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deleteTask(String uid, String taskId) =>
      _tasksRef(uid).doc(taskId).delete();
}
