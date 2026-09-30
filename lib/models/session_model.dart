import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String uid;
  final String? subject;       // null = no subject selected
  final int durationSeconds;   // total seconds the session ran
  final DateTime completedAt;

  const SessionModel({
    required this.id,
    required this.uid,
    required this.subject,
    required this.durationSeconds,
    required this.completedAt,
  });

  // ── Firestore helpers ──────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'subject': subject,
        'durationSeconds': durationSeconds,
        'completedAt': Timestamp.fromDate(completedAt),
      };

  factory SessionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      uid: d['uid'] as String,
      subject: d['subject'] as String?,
      durationSeconds: (d['durationSeconds'] as num).toInt(),
      completedAt: (d['completedAt'] as Timestamp).toDate(),
    );
  }

  // ── Convenience ───────────────────────────────────────────────────────────
  /// e.g. "25 min" or "1 h 10 min"
  String get durationLabel {
    final m = durationSeconds ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '$h h' : '$h h $rem min';
  }
}
