import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  // ── Save a completed session ───────────────────────────────────────────────
  Future<void> saveSession({
    required String uid,
    required String? subject,
    required int durationSeconds,
  }) async {
    await _sessionsRef(uid).add(SessionModel(
      id: '',
      uid: uid,
      subject: subject,
      durationSeconds: durationSeconds,
      completedAt: DateTime.now(),
    ).toMap());
  }

  // ── Fetch all sessions for a user, newest first ───────────────────────────
  Future<List<SessionModel>> getSessions(String uid) async {
    final snap = await _sessionsRef(uid)
        .orderBy('completedAt', descending: true)
        .get();
    return snap.docs.map(SessionModel.fromDoc).toList();
  }

  // ── Real-time stream (used by SessionsScreen) ─────────────────────────────
  Stream<List<SessionModel>> sessionsStream(String uid) =>
      _sessionsRef(uid)
          .orderBy('completedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(SessionModel.fromDoc).toList());
}
