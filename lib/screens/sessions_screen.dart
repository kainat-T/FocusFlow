import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';

class _C {
  static Color get surface => ThemeService().currentTheme.surface;
  static Color get border  => ThemeService().currentTheme.border;
  static Color get text    => ThemeService().currentTheme.text;
  static Color get subText => ThemeService().currentTheme.subText;
  static Color get accent  => ThemeService().currentTheme.accent;
  static Color get drawerBg=> ThemeService().currentTheme.drawerBg;
}

class SessionsScreen extends StatelessWidget {
  final String uid;
  const SessionsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionModel>>(
      stream: SessionService().sessionsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _C.accent,
              strokeWidth: 2,
            ),
          );
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return _buildEmpty();
        }

        // Group sessions by date label e.g. "Today", "Yesterday", "Mon 12 Aug"
        final grouped = _groupByDate(sessions);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: _countItems(grouped),
          itemBuilder: (context, index) {
            final item = _itemAt(grouped, index);
            if (item is String) {
              // Date header
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(
                  item.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              );
            }
            // Session card
            return _SessionCard(session: item as SessionModel);
          },
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.surface,
              border: Border.all(color: _C.border),
            ),
            child: Icon(Icons.history,
                size: 36, color: _C.subText.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions yet',
            style: TextStyle(
              color: _C.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a focus session to see it here',
            style: TextStyle(color: _C.subText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Grouping helpers ───────────────────────────────────────────────────────
  /// Returns a map of date-label → list of sessions (in insertion order)
  Map<String, List<SessionModel>> _groupByDate(List<SessionModel> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<SessionModel>> map = {};
    for (final s in sessions) {
      final d = DateTime(
          s.completedAt.year, s.completedAt.month, s.completedAt.day);
      late String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        // e.g. "Mon, 12 Aug"
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        label =
            '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
      }
      map.putIfAbsent(label, () => []).add(s);
    }
    return map;
  }

  /// Total item count = headers + sessions
  int _countItems(Map<String, List<SessionModel>> grouped) =>
      grouped.entries.fold(0, (sum, e) => sum + 1 + e.value.length);

  /// Returns either a String (header) or SessionModel at the flat index
  Object _itemAt(Map<String, List<SessionModel>> grouped, int index) {
    int i = 0;
    for (final entry in grouped.entries) {
      if (i == index) return entry.key;
      i++;
      for (final s in entry.value) {
        if (i == index) return s;
        i++;
      }
    }
    throw RangeError('index $index out of range');
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------
class _SessionCard extends StatelessWidget {
  final SessionModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(session.completedAt);
    final hasSubject = session.subject != null && session.subject!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.drawerBg,
              border: Border.all(
                color: hasSubject
                    ? _C.accent.withValues(alpha: 0.4)
                    : _C.border,
              ),
            ),
            child: Icon(
              hasSubject ? Icons.book_outlined : Icons.timer_outlined,
              size: 18,
              color: hasSubject ? _C.accent : _C.subText,
            ),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSubject ? session.subject! : 'Focus Session',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                      color: _C.subText, fontSize: 11),
                ),
              ],
            ),
          ),

          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.drawerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.border),
            ),
            child: Text(
              session.durationLabel,
              style: TextStyle(
                color: _C.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
