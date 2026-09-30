import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'profile_screen.dart';
import 'sessions_screen.dart';

// ---------------------------------------------------------------------------
// Colour palette (mirrors main.dart FFColors)
// ---------------------------------------------------------------------------
class _C {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFFFFFFFF);
  static const text = Color(0xFFFFFFFF);
  static const subText = Color(0xFFAAAAAA);
  static const accent = Color(0xFFD4A24C);
  static const drawerBg = Color(0xFF111111);
  static const navBg = Color(0xFF0D0D0D);
  static const divider = Color(0xFF2A2A2A);
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------
enum TimerState { idle, running, paused }

enum NavTab { home, stats, progress, sessions, tasks }

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── subjects ──────────────────────────────────────────────────────────────
  final List<String> _subjects = [];
  String? _selectedSubject;

  // Keys are scoped to the signed-in user so different accounts don't share subjects
  String get _kSubjectsKey =>
      'subjects_list_${AuthService().currentUser?.uid ?? 'guest'}';
  String get _kSelectedKey =>
      'selected_subject_${AuthService().currentUser?.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kSubjectsKey) ?? [];
    final selected = prefs.getString(_kSelectedKey);
    if (!mounted) return;
    setState(() {
      _subjects
        ..clear()       // always start clean — prevents duplicate on hot reload
        ..addAll(saved);
      _selectedSubject =
          (selected != null && saved.contains(selected)) ? selected : null;
    });
  }

  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSubjectsKey, List<String>.from(_subjects));
    if (_selectedSubject != null) {
      await prefs.setString(_kSelectedKey, _selectedSubject!);
    } else {
      await prefs.remove(_kSelectedKey);
    }
  }

  // ── timer ─────────────────────────────────────────────────────────────────
  static const List<_Preset> _presets = [
    _Preset('15m',  15 * 60),
    _Preset('25m',  25 * 60),
    _Preset('40m',  40 * 60),
    _Preset('1 hr', 60 * 60),
  ];

  int _selectedSeconds = 25 * 60; // currently chosen duration
  int _remaining       = 25 * 60;
  TimerState _timerState = TimerState.idle;
  Timer? _timer;

  // ── nav ───────────────────────────────────────────────────────────────────
  NavTab _currentTab = NavTab.home;

  // ── scaffold key for drawer ───────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── timer helpers ─────────────────────────────────────────────────────────
  void _startTimer() {
    final int sessionStartSeconds = _remaining;
    setState(() => _timerState = TimerState.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        setState(() => _timerState = TimerState.idle);
        _onSessionCompleted(sessionStartSeconds);
        return;
      }
      setState(() => _remaining--);
    });
  }

  /// Called when the countdown reaches zero — saves session to Firestore.
  void _onSessionCompleted(int totalSeconds) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    SessionService().saveSession(
      uid: uid,
      subject: _selectedSubject,
      durationSeconds: totalSeconds,
    );
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerState = TimerState.paused);
  }

  void _resumeTimer() => _startTimer();

  void _restartTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _selectedSeconds;
      _timerState = TimerState.idle;
    });
  }

  // ── preset / custom duration selection ────────────────────────────────────
  void _selectPreset(int seconds) {
    if (_timerState != TimerState.idle) return;
    setState(() {
      _selectedSeconds = seconds;
      _remaining = seconds;
    });
  }

  Future<void> _pickCustomTime() async {
    if (_timerState != TimerState.idle) return;

    int hours   = _selectedSeconds ~/ 3600;
    int minutes = (_selectedSeconds % 3600) ~/ 60;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _CustomTimeDialog(initialHours: hours, initialMinutes: minutes),
    );

    if (result != null && result > 0) {
      setState(() {
        _selectedSeconds = result;
        _remaining       = result;
      });
    }
  }

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── subject dialog ────────────────────────────────────────────────────────
  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        title: const Text('Add Subject',
            style: TextStyle(color: _C.text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _C.text),
          cursorColor: _C.accent,
          decoration: InputDecoration(
            hintText: 'e.g. Mathematics',
            hintStyle: const TextStyle(color: _C.subText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.accent),
            ),
          ),
          onSubmitted: (_) => _confirmAdd(controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: _C.subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent),
            onPressed: () => _confirmAdd(controller),
            child: const Text('Add',
                style: TextStyle(color: Colors.black,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAdd(TextEditingController c) {
    final name = c.text.trim();
    if (name.isNotEmpty && !_subjects.contains(name)) {
      setState(() => _subjects.add(name));
      _saveSubjects();
    }
    Navigator.pop(context);
  }

  // ── subject popup ─────────────────────────────────────────────────────────
  void _showSubjectMenu(BuildContext btnCtx) async {
    final RenderBox box = btnCtx.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    final items = <PopupMenuEntry<String>>[
      ..._subjects.map(
        (s) => PopupMenuItem<String>(
          value: s,
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 8,
                  color: _selectedSubject == s ? _C.accent : _C.subText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s,
                    style: TextStyle(
                        color: _selectedSubject == s ? _C.accent : _C.text)),
              ),
              // Delete button — tap without closing the parent menu
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context); // close menu
                  setState(() {
                    _subjects.remove(s);
                    if (_selectedSubject == s) _selectedSubject = null;
                  });
                  _saveSubjects();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close, size: 14, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_subjects.isNotEmpty) const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: '__add__',
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: _C.accent),
            SizedBox(width: 8),
            Text('Add subject', style: TextStyle(color: _C.accent)),
          ],
        ),
      ),
    ];

    // If no subjects yet, only show Add subject
    final menuItems = _subjects.isEmpty
        ? [
            const PopupMenuItem<String>(
              value: '__add__',
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: _C.accent),
                  SizedBox(width: 8),
                  Text('Add subject', style: TextStyle(color: _C.accent)),
                ],
              ),
            ),
          ]
        : items;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        0,
      ),
      color: _C.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      items: menuItems,
    );

    if (result == '__add__') {
      _showAddSubjectDialog();
    } else if (result != null) {
      setState(() => _selectedSubject = result);
      _saveSubjects();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bg,
      // ── App bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Focus Flow',
          style: TextStyle(
            color: _C.text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _C.text),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      // ── Drawer ─────────────────────────────────────────────────────────
      drawer: _buildDrawer(),
      // ── Body ───────────────────────────────────────────────────────────
      body: _currentTab == NavTab.home
          ? _buildHomeBody()
          : _buildPlaceholder(_currentTab),
      // ── Bottom Nav ─────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Home body ─────────────────────────────────────────────────────────────
  Widget _buildHomeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject selector + Duration picker on the same row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Subject selector — warm gold pill
              Builder(
                builder: (btnCtx) => GestureDetector(
                  onTap: () => _showSubjectMenu(btnCtx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSubject != null
                          ? const Color(0xFFD4A24C).withValues(alpha: 0.15)
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _selectedSubject != null
                            ? const Color(0xFFD4A24C).withValues(alpha: 0.6)
                            : const Color(0xFF333333),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedSubject != null
                              ? Icons.book_outlined
                              : Icons.add_circle_outline,
                          size: 14,
                          color: _selectedSubject != null
                              ? const Color(0xFFD4A24C)
                              : const Color(0xFF888888),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _selectedSubject ?? 'Subject',
                          style: TextStyle(
                            color: _selectedSubject != null
                                ? const Color(0xFFD4A24C)
                                : const Color(0xFF888888),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _selectedSubject != null
                              ? const Color(0xFFD4A24C)
                              : const Color(0xFF666666),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Duration pill — slate/blue tint
              Builder(
                builder: (btnCtx) => GestureDetector(
                  onTap: _timerState == TimerState.idle
                      ? () => _showDurationMenu(btnCtx)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _timerState == TimerState.idle
                          ? const Color(0xFF8B93A6).withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _timerState == TimerState.idle
                            ? const Color(0xFF8B93A6).withValues(alpha: 0.5)
                            : const Color(0xFF2A2A2A),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 13,
                          color: _timerState == TimerState.idle
                              ? const Color(0xFF8B93A6)
                              : const Color(0xFF555555),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _durationLabel(_selectedSeconds),
                          style: TextStyle(
                            color: _timerState == TimerState.idle
                                ? const Color(0xFFB0B8CC)
                                : const Color(0xFF555555),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _timerState == TimerState.idle
                              ? const Color(0xFF8B93A6)
                              : const Color(0xFF444444),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Timer area – sits in upper-centre of the remaining space
        Expanded(
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular timer
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _TimerRingPainter(
                      progress: _remaining / _selectedSeconds,
                      trackColor: _C.divider,
                      arcColor: _timerState == TimerState.idle
                          ? _C.border
                          : _timerState == TimerState.paused
                              ? _C.subText
                              : _C.accent,
                      strokeWidth: 4,
                    ),
                    child: Center(
                      child: Text(
                        _timeLabel,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 58,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Buttons
                _buildTimerButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Preset chips row ──────────────────────────────────────────────────────
  // ── Duration dropdown menu ────────────────────────────────────────────────
  void _showDurationMenu(BuildContext btnCtx) async {
    final RenderBox box = btnCtx.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    final menuItems = <PopupMenuEntry<int>>[
      ..._presets.map((p) => PopupMenuItem<int>(
            value: p.seconds,
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 15,
                    color: _selectedSeconds == p.seconds
                        ? _C.accent
                        : _C.subText),
                const SizedBox(width: 10),
                Text(
                  p.label,
                  style: TextStyle(
                    color: _selectedSeconds == p.seconds
                        ? _C.accent
                        : _C.text,
                    fontWeight: _selectedSeconds == p.seconds
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          )),
      const PopupMenuDivider(),
      PopupMenuItem<int>(
        value: -1, // sentinel for custom
        child: Row(
          children: [
            const Icon(Icons.tune, size: 15, color: _C.accent),
            const SizedBox(width: 10),
            Text(
              'Custom',
              style: TextStyle(
                color: !_presets.any((p) => p.seconds == _selectedSeconds)
                    ? _C.accent
                    : _C.text,
              ),
            ),
          ],
        ),
      ),
    ];

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        0,
      ),
      color: _C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: menuItems,
    );

    if (result == null) return;
    if (result == -1) {
      _pickCustomTime();
    } else {
      _selectPreset(result);
    }
  }

  /// Short label shown on the dropdown button e.g. "25 min", "1 hr", "48 min"
  String _durationLabel(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '$h hr' : '$h hr $rem min';
  }

  // ── Timer buttons ─────────────────────────────────────────────────────────
  Widget _buildTimerButtons() {
    if (_timerState == TimerState.idle) {
      return _pill(
        label: 'Start',
        onTap: _startTimer,
        filled: false,
      );
    }

    if (_timerState == TimerState.running) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pill(label: 'Pause', onTap: _pauseTimer, filled: false),
          const SizedBox(width: 12),
          _pill(label: 'Restart', onTap: _restartTimer, filled: false),
        ],
      );
    }

    // paused
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pill(label: 'Resume', onTap: _resumeTimer, filled: false),
        const SizedBox(width: 12),
        _pill(label: 'Restart', onTap: _restartTimer, filled: false),
      ],
    );
  }

  Widget _pill({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _C.text, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _C.text,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.navBg,
        border: Border(top: BorderSide(color: _C.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(NavTab.home, Icons.timer_outlined, Icons.timer,
                  'Timer'),
              _navIcon(NavTab.stats, Icons.bar_chart_outlined,
                  Icons.bar_chart, 'Stats'),
              _navIcon(NavTab.progress, Icons.trending_up_outlined,
                  Icons.trending_up, 'Progress'),
              _navIcon(NavTab.sessions, Icons.history_outlined,
                  Icons.history, 'Sessions'),
              _navIcon(
                  NavTab.tasks, Icons.task_alt_outlined, Icons.task_alt, 'Tasks'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(
      NavTab tab, IconData outlineIcon, IconData filledIcon, String label) {
    final active = _currentTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? filledIcon : outlineIcon,
              color: active ? _C.accent : _C.subText,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? _C.accent : _C.subText,
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Placeholder for non-home tabs ─────────────────────────────────────────
  Widget _buildPlaceholder(NavTab tab) {
    if (tab == NavTab.sessions) {
      final uid = AuthService().currentUser?.uid ?? '';
      return SessionsScreen(uid: uid);
    }

    final labels = {
      NavTab.stats: ('Weekly Study Stats', Icons.bar_chart),
      NavTab.progress: ('Progress Dashboard', Icons.trending_up),
      NavTab.tasks: ('Task Management', Icons.task_alt),
    };
    final info = labels[tab]!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(info.$2, size: 64, color: _C.subText),
          const SizedBox(height: 16),
          Text(
            info.$1,
            style: const TextStyle(
                color: _C.subText,
                fontSize: 20,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(color: _C.divider, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _C.drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _C.surface,
                    child: const Icon(Icons.person,
                        size: 36, color: _C.subText),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AuthService().currentUser?.displayName ?? 'Focus Flow',
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AuthService().currentUser?.email ?? 'Stay focused, stay ahead',
                    style: const TextStyle(color: _C.subText, fontSize: 12),
                  ),
                ],
              ),
            ),

            Divider(color: _C.divider, thickness: 0.5,
                indent: 20, endIndent: 20),
            const SizedBox(height: 8),

            // Menu items
            _drawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _drawerItem(
              icon: Icons.palette_outlined,
              label: 'App Theme',
              onTap: () {
                Navigator.pop(context);
                _showSnack('Theme settings – coming soon');
              },
            ),
            _drawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                _showSnack('Settings – coming soon');
              },
            ),

            const Spacer(),

            Divider(color: _C.divider, thickness: 0.5,
                indent: 20, endIndent: 20),

            _drawerItem(
              icon: Icons.logout,
              label: 'Logout',
              iconColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context); // close drawer first
                await AuthService().logout();
                // AuthGate's StreamBuilder handles the redirect to LoginScreen
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = _C.subText,
    Color labelColor = _C.text,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(label,
          style: TextStyle(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      horizontalTitleGap: 8,
      onTap: onTap,
      hoverColor: _C.surface,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------------------------------------------------------------
// Preset data class
// ---------------------------------------------------------------------------
class _Preset {
  final String label;
  final int seconds;
  const _Preset(this.label, this.seconds);
}

// ---------------------------------------------------------------------------
// Custom time picker dialog
// ---------------------------------------------------------------------------
class _CustomTimeDialog extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  const _CustomTimeDialog({
    required this.initialHours,
    required this.initialMinutes,
  });

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours   = widget.initialHours;
    _minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Custom Duration',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hours
              _SpinnerColumn(
                label: 'Hours',
                value: _hours,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _hours = v),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  ' : ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300),
                ),
              ),
              // Minutes
              _SpinnerColumn(
                label: 'Minutes',
                value: _minutes,
                min: 0,
                max: 59,
                onChanged: (v) => setState(() => _minutes = v),
              ),
            ],
          ),
          if (_hours == 0 && _minutes == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Set at least 1 minute',
                style:
                    TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFFAAAAAA))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4A24C),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: (_hours == 0 && _minutes == 0)
              ? null
              : () => Navigator.pop(
                  context, _hours * 3600 + _minutes * 60),
          child: const Text('Set',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spinner column widget used inside _CustomTimeDialog
// ---------------------------------------------------------------------------
class _SpinnerColumn extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SpinnerColumn({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFFD4A24C)),
          padding: EdgeInsets.zero,
        ),
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFFD4A24C)),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              color: Color(0xFF666666), fontSize: 11),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timer ring painter
// ---------------------------------------------------------------------------
class _TimerRingPainter extends CustomPainter {
  final double progress;   // 1.0 = full, 0.0 = empty
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track ring (full dim circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — starts at top (–π/2), sweeps clockwise
    final sweepAngle = 2 * math.pi * progress;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect,
      -math.pi / 2,       // start at 12 o'clock
      sweepAngle,         // sweep proportional to remaining time
      false,
      arcPaint,
    );

    // Dot at the shrinking tip (end of the arc)
    if (progress > 0) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);

      // Slightly larger white filled circle
      final dotPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.85, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}


